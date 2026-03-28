"""IEEE 33-Bus fault detection for ParallelPulse.

Monitors the gsy-e simulation Area tree for power imbalances and injects
synthetic line-fail events on a rotating schedule to demonstrate the
EmergencyMode flow during the hackathon demo.

Platform note: Must run on Linux/macOS/WSL2 (not native Windows).
"""
from __future__ import annotations

import logging
import threading
import time
from typing import TYPE_CHECKING

from .schemas import FaultSignal

if TYPE_CHECKING:
    from .monad_bridge import MonadBridge

logger = logging.getLogger(__name__)

# IEEE 33-bus critical nodes: hospitals and schools at buses 6, 9, 17, 25.
# Bus 1 is the substation (always critical).
CRITICAL_BUS_IDS: list[int] = [1, 6, 9, 17, 25]

# Buses that will be rotated through for synthetic fault injection.
FAULT_BUS_SEQUENCE: list[int] = [33, 28, 18, 12, 7]

# Critical load names must match the Area names used in ieee33_bus.py.
CRITICAL_LOAD_NAMES: list[str] = [
    "Hospital_Bus6",
    "School_Bus9",
    "Hospital_Bus17",
    "School_Bus25",
]


class IEEE33FaultDetector:
    """Detects faults in the IEEE 33-bus simulation and triggers EmergencyMode.

    This class runs a background daemon thread that:
    1. Monitors BESS assets for low State-of-Charge (proxy for overload).
    2. Injects synthetic line-open faults on FAULT_BUS_SEQUENCE rotation.
    3. Calls MonadBridge.emit_fault_signal() for each detected fault.

    Args:
        bridge: Configured MonadBridge instance.
        fault_interval_s: Seconds between fault injection cycles.
        soc_threshold_pct: BESS SOC percentage below which an overload is flagged.
        bess_strategies: List of BESSEmergencyStrategy instances to monitor.
    """

    def __init__(
        self,
        bridge: "MonadBridge",
        fault_interval_s: float = 30.0,
        soc_threshold_pct: float = 20.0,
        bess_strategies: list | None = None,
    ) -> None:
        self._bridge = bridge
        self._fault_interval_s = fault_interval_s
        self._soc_threshold_pct = soc_threshold_pct
        self._bess_strategies: list = bess_strategies or []
        self._fault_sequence_index: int = 0
        self._stop_event = threading.Event()
        self._last_fault_signal: FaultSignal | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def add_bess_strategy(self, strategy: object) -> None:
        """Register a BESSEmergencyStrategy instance for SOC monitoring."""
        self._bess_strategies.append(strategy)

    def run_fault_loop(self) -> None:
        """Main fault detection loop — call in a daemon thread.

        Runs until stop() is called. Each iteration:
        1. Checks for BESS overload (low SOC).
        2. If no real fault, injects a synthetic line-open fault.
        3. Waits fault_interval_s before the next check.
        """
        logger.info(
            "IEEE33FaultDetector started. Interval: %.1fs, SOC threshold: %.0f%%",
            self._fault_interval_s,
            self._soc_threshold_pct,
        )
        while not self._stop_event.is_set():
            try:
                signal = self._detect_real_fault() or self._inject_synthetic_fault()
                if signal:
                    self._emit(signal)
            except Exception as exc:  # noqa: BLE001
                logger.error("Fault loop error: %s", exc, exc_info=True)
            self._stop_event.wait(timeout=self._fault_interval_s)

    def stop(self) -> None:
        """Signal the fault loop to stop after the current sleep."""
        self._stop_event.set()

    def start_daemon(self) -> threading.Thread:
        """Start the fault loop in a daemon thread and return it."""
        t = threading.Thread(target=self.run_fault_loop, daemon=True, name="fault-detector")
        t.start()
        return t

    @property
    def last_fault_signal(self) -> FaultSignal | None:
        """Most recent FaultSignal emitted, or None if none yet."""
        return self._last_fault_signal

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _detect_real_fault(self) -> FaultSignal | None:
        """Inspect BESS SOC readings for overload indicators.

        Returns a FaultSignal if any BESS device is below the SOC threshold,
        or None if the system appears healthy.
        """
        for strategy in self._bess_strategies:
            try:
                soc = strategy.get_soc_percent()
            except Exception:  # noqa: BLE001
                continue
            if soc < self._soc_threshold_pct:
                logger.info(
                    "BESS overload detected. SOC: %.1f%% < threshold %.1f%%",
                    soc,
                    self._soc_threshold_pct,
                )
                return FaultSignal.overload(
                    bus_id=CRITICAL_BUS_IDS[0],
                    affected_loads=CRITICAL_LOAD_NAMES,
                    critical_load_ids=CRITICAL_LOAD_NAMES,
                )
        return None

    def _inject_synthetic_fault(self) -> FaultSignal:
        """Generate a rotating synthetic line-open fault for demo purposes.

        Uses FAULT_BUS_SEQUENCE in round-robin so each demo cycle faults a
        different bus, making the visualisation more compelling.
        """
        bus_id = FAULT_BUS_SEQUENCE[self._fault_sequence_index % len(FAULT_BUS_SEQUENCE)]
        self._fault_sequence_index += 1

        affected = self._loads_near_bus(bus_id)
        critical = [name for name in CRITICAL_LOAD_NAMES if name in affected]

        logger.info(
            "Injecting synthetic LINE_OPEN fault on bus %d. Affected loads: %s",
            bus_id,
            affected,
        )
        return FaultSignal.line_open(
            bus_id=bus_id,
            affected_loads=affected,
            critical_load_ids=critical or CRITICAL_LOAD_NAMES[:2],
        )

    def _loads_near_bus(self, bus_id: int) -> list[str]:
        """Return a list of load names plausibly near a given bus.

        In a hackathon context this is a lookup table; a production system
        would derive this from the actual grid topology.
        """
        # Buses ≥ 20 are on the downstream feeder — map to generic loads.
        if bus_id >= 20:
            return [f"Load_Bus{bus_id}", f"Load_Bus{bus_id - 1}", "Hospital_Bus17"]
        if bus_id >= 10:
            return [f"Load_Bus{bus_id}", "School_Bus9", "Hospital_Bus6"]
        return [f"Load_Bus{bus_id}", "Hospital_Bus6"]

    def _emit(self, signal: FaultSignal) -> None:
        """Emit a fault signal to Monad via the bridge, with error handling."""
        self._last_fault_signal = signal
        try:
            tx_hash = self._bridge.emit_fault_signal(signal)
            logger.info("Fault signal emitted. TxHash: %s", tx_hash)
        except Exception as exc:  # noqa: BLE001
            logger.error(
                "Failed to emit fault signal for bus %d: %s", signal.bus_id, exc, exc_info=True
            )
