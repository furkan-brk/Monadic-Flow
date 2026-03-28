"""ParallelPulse simulation runner.

Entry point that starts the gsy-e IEEE 33-bus simulation alongside the
fault detector and periodically pushes SOC readings to the FastAPI backend.

Usage (from WSL2):
    cd /mnt/c/Projeler/Monadic-Flow/energy
    python -m parallel_pulse.runner

Required environment variables (in .env or shell):
    MONAD_RPC_URL      — Monad HTTP RPC endpoint
    CONTRACT_ADDRESS   — Deployed EnergyMarket address
    PRIVATE_KEY        — Hex-encoded signing key
    BACKEND_URL        — FastAPI service base URL (default: http://localhost:8000)
    INTERNAL_TOKEN     — Secret for /internal/soc endpoint
    BESS_ADDRESS       — Ethereum address representing the simulated BESS device

Platform: Linux/macOS/WSL2 only.
"""
from __future__ import annotations

import logging
import os
import sys
import threading
import time
from pathlib import Path

import httpx
from dotenv import load_dotenv

# Load .env from the project root (Monadic-Flow/.env) — single source of truth.
# energy/parallel_pulse/runner.py → energy/parallel_pulse/ → energy/ → root/
_ENV_PATH = Path(__file__).parent.parent.parent / ".env"
load_dotenv(_ENV_PATH)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("parallelpulse.runner")

BACKEND_URL = os.environ.get("BACKEND_URL", "http://localhost:8000")
INTERNAL_TOKEN = os.environ.get("INTERNAL_TOKEN", "parallelpulse-internal-secret")
BESS_ADDRESS = os.environ.get("BESS_ADDRESS", "0x0000000000000000000000000000000000000001")

# SOC push interval — one push per simulated market cycle (15 min = 15s wall-clock in fast mode)
SOC_PUSH_INTERVAL_S: float = float(os.environ.get("SOC_PUSH_INTERVAL_S", "15"))


def _push_soc(soc_percent: float, earnings_wei: int, bess_address: str = BESS_ADDRESS) -> None:
    """HTTP POST SOC reading to the backend /internal/soc endpoint.

    Args:
        soc_percent: Current battery state of charge (0–100).
        earnings_wei: Accumulated earnings in wei from the contract.
        bess_address: Ethereum address of the BESS device.
    """
    payload = {
        "bess_address": bess_address,
        "soc_percent": round(soc_percent, 2),
        "earnings_wei": earnings_wei,
    }
    try:
        with httpx.Client(timeout=5.0) as client:
            resp = client.post(
                f"{BACKEND_URL}/internal/soc",
                json=payload,
                headers={"X-Internal-Token": INTERNAL_TOKEN},
            )
            if resp.status_code != 200:
                logger.warning("SOC push returned HTTP %d: %s", resp.status_code, resp.text)
    except httpx.RequestError as exc:
        logger.warning("SOC push failed (backend unreachable?): %s", exc)


def _soc_push_loop(
    detector,  # IEEE33FaultDetector
    bridge,    # MonadBridge
    stop_event: threading.Event,
) -> None:
    """Background thread: periodically push SOC readings to the backend.

    Reads SOC from registered BESS strategies; if none are registered yet,
    generates a sawtooth demo waveform so the Flutter dashboard has data.
    """
    tick = 0
    while not stop_event.is_set():
        soc: float
        earnings_wei: int = 0

        if detector._bess_strategies:  # noqa: SLF001
            # Real SOC from the first registered BESS strategy
            try:
                soc = detector._bess_strategies[0].get_soc_percent()  # noqa: SLF001
            except Exception:  # noqa: BLE001
                soc = max(0.0, 80.0 - tick * 2.5) % 100
        else:
            # Demo sawtooth: 80 → 10 → 80 → … over 28 cycles
            soc = max(10.0, 80.0 - (tick % 28) * 2.5)

        try:
            earnings_wei = bridge.get_earnings(BESS_ADDRESS)
        except Exception:  # noqa: BLE001
            pass  # contract not yet deployed or RPC issue — continue

        _push_soc(soc, earnings_wei)
        tick += 1
        stop_event.wait(timeout=SOC_PUSH_INTERVAL_S)


def run_simulation_standalone(stop_event: threading.Event) -> None:
    """Run gsy-e IEEE 33-bus simulation in a background thread.

    This imports gsy-e's simulation runner and calls it with the
    ieee33_bus setup module. Exits when the simulation finishes or
    stop_event is set.
    """
    try:
        from gsy_e.gsy_e_core.simulation.simulation import run_simulation  # type: ignore[import]
        from gsy_e.gsy_e_core.enums import SpotMarketTypeEnum  # type: ignore[import]

        logger.info("Starting gsy-e IEEE 33-bus simulation…")
        # run_simulation blocks until the sim completes
        run_simulation(
            setup_module_name="ieee33_bus",
            duration=None,   # uses setup module default (24h sim)
            slot_length=None,
            tick_length=None,
            market_type=SpotMarketTypeEnum.TWO_SIDED,
            no_export=True,
        )
        logger.info("gsy-e simulation completed.")
    except ImportError:
        logger.warning(
            "gsy-e not importable (not installed or not on Linux/WSL2). "
            "Running in SOC-demo-only mode."
        )
    except Exception as exc:  # noqa: BLE001
        logger.error("Simulation error: %s", exc, exc_info=True)
    finally:
        stop_event.set()


def main() -> int:
    """Entrypoint: start simulation + fault detection + SOC push loop."""
    # Validate required environment variables
    missing = [v for v in ("RPC_URL", "CONTRACT_ADDRESS", "PRIVATE_KEY") if not os.environ.get(v)]
    if missing:
        logger.error(
            "Missing required environment variables: %s\n"
            "Copy .env.example to .env in the project root and fill in the values.",
            ", ".join(missing),
        )
        return 1

    from .monad_bridge import MonadBridge, from_env
    from .fault_detector import IEEE33FaultDetector

    bridge = from_env()
    detector = IEEE33FaultDetector(bridge=bridge, fault_interval_s=30.0)
    stop_event = threading.Event()

    # Thread 1: gsy-e simulation (blocks until done)
    sim_thread = threading.Thread(
        target=run_simulation_standalone,
        args=(stop_event,),
        daemon=False,
        name="gsy-e-simulation",
    )

    # Thread 2: fault detection loop
    fault_thread = detector.start_daemon()

    # Thread 3: SOC push loop
    soc_thread = threading.Thread(
        target=_soc_push_loop,
        args=(detector, bridge, stop_event),
        daemon=True,
        name="soc-pusher",
    )

    logger.info("ParallelPulse runner starting. BESS address: %s", BESS_ADDRESS)
    sim_thread.start()
    soc_thread.start()

    try:
        sim_thread.join()
    except KeyboardInterrupt:
        logger.info("Interrupted — stopping fault detector…")
        detector.stop()
        stop_event.set()
    finally:
        detector.stop()
        stop_event.set()
        fault_thread.join(timeout=5.0)
        soc_thread.join(timeout=3.0)
        logger.info("ParallelPulse runner stopped.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
