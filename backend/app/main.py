import asyncio
import logging
import time
from typing import Set

from fastapi import FastAPI, WebSocket, WebSocketDisconnect, HTTPException, Header
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .models import BESSStateResponse, EventMessage, OfferPayload, SOCUpdatePayload
from .grid_topology import build_grid_status_update, bess_address_to_bus
from .community import get_community_state

# web3 is optional on Windows (ckzg build requires MSVC).
# Chain listener is disabled automatically when web3 is unavailable.
try:
    from web3 import Web3
    from .chain_listener import ChainEventListener, MINIMAL_ABI
    _WEB3_AVAILABLE = True
except ImportError:
    Web3 = None  # type: ignore[assignment,misc]
    ChainEventListener = None  # type: ignore[assignment,misc]
    MINIMAL_ABI = []  # type: ignore[assignment]
    _WEB3_AVAILABLE = False
    logger_tmp = __import__("logging").getLogger(__name__)
    logger_tmp.warning(
        "web3 not installed — chain listener disabled. "
        "Install with: pip install web3  (requires Linux/WSL2 for ckzg build)"
    )

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = FastAPI(title="ParallelPulse Backend", version="2.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# WebSocket connection manager
# ---------------------------------------------------------------------------

connected_websockets: Set[WebSocket] = set()


async def _broadcast(message: str) -> None:
    """Send *message* to every connected WebSocket client.

    Dead connections are collected and removed from the set.
    """
    dead: Set[WebSocket] = set()
    for ws in connected_websockets.copy():
        try:
            await ws.send_text(message)
        except Exception as exc:
            logger.debug("WebSocket send failed (%s); marking as dead.", exc)
            dead.add(ws)
    for ws in dead:
        connected_websockets.discard(ws)


# ---------------------------------------------------------------------------
# Sprint 2: In-memory BESS SOC state (bus_id → soc_percent).
# Updated by /internal/soc; read by ChainEventListener for GridStatusUpdate.
# ---------------------------------------------------------------------------

_bess_soc_by_bus: dict[int, float] = {
    12: 80.0,  # BESS_B default
    22: 80.0,  # BESS_A default
}


def _get_bess_soc() -> dict[int, float]:
    """Getter passed to ChainEventListener so it can embed fresh SOC data."""
    return dict(_bess_soc_by_bus)


# ---------------------------------------------------------------------------
# Web3 / contract setup
# ---------------------------------------------------------------------------

_zero_address = "0x0000000000000000000000000000000000000000"

w3 = None
contract = None
listener = None

if _WEB3_AVAILABLE and Web3 is not None:
    w3 = Web3(Web3.HTTPProvider(settings.rpc_url))
    if settings.contract_address != _zero_address:
        try:
            contract = w3.eth.contract(
                address=Web3.to_checksum_address(settings.contract_address),
                abi=MINIMAL_ABI,
            )
            logger.info("Contract loaded at %s", settings.contract_address)
        except Exception as exc:
            logger.warning("Could not load contract: %s", exc)

    if contract is not None:
        listener = ChainEventListener(w3, contract, _broadcast, soc_getter=_get_bess_soc)

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------


@app.on_event("startup")
async def _startup() -> None:
    if listener is not None:
        asyncio.create_task(listener.listen_loop())
        logger.info("ChainEventListener task started.")
    else:
        logger.info(
            "Contract address is zero / unset — chain listener disabled. "
            "Internal SOC relay is active."
        )


# ---------------------------------------------------------------------------
# WebSocket endpoint
# ---------------------------------------------------------------------------


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()
    connected_websockets.add(websocket)
    client = websocket.client
    logger.info("WebSocket client connected: %s", client)

    # Send an initial GridStatusUpdate so new clients immediately see current
    # BESS SOC without waiting for the next simulation tick.
    try:
        init_payload = build_grid_status_update(bess_soc_map=_get_bess_soc())
        init_msg = EventMessage(**init_payload)
        await websocket.send_text(init_msg.model_dump_json())
    except Exception as exc:
        logger.warning("Could not send initial GridStatusUpdate: %s", exc)

    try:
        while True:
            # Keep the connection alive; clients may send ping frames or text.
            await websocket.receive_text()
    except WebSocketDisconnect:
        logger.info("WebSocket client disconnected: %s", client)
    except Exception as exc:
        logger.warning("WebSocket error for %s: %s", client, exc)
    finally:
        connected_websockets.discard(websocket)


# ---------------------------------------------------------------------------
# REST endpoints
# ---------------------------------------------------------------------------


@app.get("/bess/{address}/state", response_model=BESSStateResponse)
async def get_bess_state(address: str) -> BESSStateResponse:
    """Read on-chain BESS state for the given address.

    Requires a non-zero CONTRACT_ADDRESS to be configured.
    """
    if contract is None:
        raise HTTPException(
            status_code=503,
            detail="Contract not configured — set CONTRACT_ADDRESS in .env",
        )
    if not _WEB3_AVAILABLE or Web3 is None:
        raise HTTPException(status_code=503, detail="web3 not installed on this host.")

    try:
        checksum = Web3.to_checksum_address(address)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid Ethereum address.")

    loop = asyncio.get_event_loop()
    try:
        emergency_mode: bool = await loop.run_in_executor(
            None, contract.functions.emergencyMode().call
        )
        earnings_wei: int = await loop.run_in_executor(
            None, contract.functions.earnings(checksum).call
        )
        offer_amount_wh: int = await loop.run_in_executor(
            None, contract.functions.offerAmount(checksum).call
        )
    except Exception as exc:
        logger.error("Contract call failed: %s", exc)
        raise HTTPException(status_code=502, detail=f"Contract call failed: {exc}")

    # Treat offerAmount as a proxy for SoC (0–100 kWh range → 0–100 %).
    MAX_CAPACITY_WH = 100_000  # 100 kWh reference capacity
    soc_percent = min(float(offer_amount_wh) / MAX_CAPACITY_WH * 100.0, 100.0)

    return BESSStateResponse(
        bess_address=checksum,
        soc_percent=soc_percent,
        earnings_wei=earnings_wei,
        emergency_mode=emergency_mode,
    )


@app.post("/internal/soc", status_code=200)
async def post_soc_update(
    payload: SOCUpdatePayload,
    x_internal_token: str = Header(default=""),
) -> dict:
    """Called by the Python simulation runner each market cycle.

    Validates the shared secret, broadcasts an SOCUpdate EventMessage to all
    connected WebSocket clients, and follows up with a GridStatusUpdate so the
    Flutter grid painter can reflect the new BESS SOC immediately.
    """
    if x_internal_token != settings.internal_token:
        raise HTTPException(status_code=401, detail="Invalid internal token.")

    timestamp_ms = (
        payload.timestamp_ms if payload.timestamp_ms is not None else int(time.time() * 1000)
    )

    # --- 1. Broadcast the primary SOCUpdate event ---
    soc_msg = EventMessage(
        event_type="SOCUpdate",
        bess_address=payload.bess_address,
        soc_percent=payload.soc_percent,
        earnings_wei=payload.earnings_wei,
        timestamp_ms=timestamp_ms,
    )
    await _broadcast(soc_msg.model_dump_json())
    logger.info(
        "SOCUpdate broadcast: bess=%s soc=%.1f%% earnings=%d wei",
        payload.bess_address,
        payload.soc_percent,
        payload.earnings_wei,
    )

    # --- 2. Update in-memory SOC cache ---
    bess_bus = bess_address_to_bus(
        payload.bess_address,
        settings.bess_a_address,
        settings.bess_b_address,
    )
    if bess_bus is not None:
        _bess_soc_by_bus[bess_bus] = payload.soc_percent
    else:
        # Unknown address — assume it's BESS_B (Bus 12) as per the runner default.
        _bess_soc_by_bus[12] = payload.soc_percent

    # --- 3. Broadcast GridStatusUpdate with refreshed SOC map ---
    grid_payload = build_grid_status_update(bess_soc_map=_get_bess_soc())
    grid_msg = EventMessage(**grid_payload)
    await _broadcast(grid_msg.model_dump_json())

    return {"status": "broadcast", "clients": len(connected_websockets)}


@app.get("/health")
async def health() -> dict:
    """Simple liveness check."""
    return {
        "status": "ok",
        "connected_clients": len(connected_websockets),
        "bess_soc": _bess_soc_by_bus,
    }


# ---------------------------------------------------------------------------
# Sprint 3: Community REST endpoints
# ---------------------------------------------------------------------------


@app.get("/community/stats")
async def get_community_stats() -> dict:
    """Return aggregated energy community statistics for the current session.

    These are in-memory accumulators reset on each backend restart.
    Consumed by the Flutter CommunityScreen on initial load.
    """
    state = get_community_state()
    return state.to_stats_dict()


@app.get("/community/leaderboard")
async def get_community_leaderboard() -> dict:
    """Return the top BESS providers sorted by cumulative earnings (desc).

    Each entry contains: address, earnings_wei, total_energy_wh, rank.
    """
    state = get_community_state()
    return {
        "leaderboard": state.sorted_leaderboard(),
        "settlement_count": state.settlement_count,
    }


@app.get("/community/feed")
async def get_community_feed(limit: int = 20) -> dict:
    """Return the most recent energy transfer records.

    Args:
        limit: Maximum number of records to return (default 20, max 50).
    """
    state = get_community_state()
    return {"transfers": state.recent_transfers(limit=min(limit, 50))}


@app.post("/bess/offer")
async def submit_bess_offer(payload: OfferPayload) -> dict:
    """BESS owner submits an energy offer during emergency mode.

    Two-tier execution:
      1) If contract + BESS_PRIVATE_KEY are configured → real on-chain TX via
         ``submitEnergyOffer(amount, price)``.
      2) Otherwise → deterministic demo tx_hash so the UI flow still works.

    Always broadcasts an ``OfferSubmitted`` WebSocket event to all clients.
    """
    import re
    import hashlib

    # Basic address format validation.
    if not re.fullmatch(r"0x[0-9a-fA-F]{40}", payload.wallet_address):
        raise HTTPException(status_code=400, detail="Invalid Ethereum address format.")
    if payload.amount_wh <= 0:
        raise HTTPException(status_code=400, detail="amount_wh must be positive.")

    timestamp_ms = int(time.time() * 1000)
    bess_private_key = __import__("os").getenv("BESS_PRIVATE_KEY", "")

    tx_hash: str
    status: str

    if contract is not None and bess_private_key:
        # Real on-chain submission.
        try:
            loop = asyncio.get_event_loop()
            tx_hash_bytes = await loop.run_in_executor(
                None,
                lambda: w3.eth.send_raw_transaction(
                    w3.eth.account.sign_transaction(
                        contract.functions.submitEnergyOffer(
                            payload.amount_wh,
                            payload.price_wei_per_wh,
                        ).build_transaction({
                            "from": payload.wallet_address,
                            "nonce": w3.eth.get_transaction_count(payload.wallet_address),
                            "gas": 150_000,
                            "gasPrice": w3.eth.gas_price,
                        }),
                        bess_private_key,
                    ).rawTransaction
                ),
            )
            tx_hash = tx_hash_bytes.hex()
            status = "submitted"
        except Exception as exc:
            logger.warning("Real TX failed (%s); falling back to demo hash.", exc)
            tx_hash = "0x" + hashlib.sha256(
                f"{payload.wallet_address}{payload.amount_wh}{timestamp_ms}".encode()
            ).hexdigest()
            status = "demo"
    else:
        # Demo mode — deterministic hash.
        tx_hash = "0x" + hashlib.sha256(
            f"{payload.wallet_address}{payload.amount_wh}{timestamp_ms}".encode()
        ).hexdigest()
        status = "demo"

    # Broadcast OfferSubmitted event to all WS clients.
    offer_msg = EventMessage(
        event_type="OfferSubmitted",
        bess_address=payload.wallet_address,
        amount_wh=payload.amount_wh,
        timestamp_ms=timestamp_ms,
    )
    await _broadcast(offer_msg.model_dump_json())
    logger.info(
        "OfferSubmitted: wallet=%s amount=%d Wh price=%d wei/Wh tx=%s status=%s",
        payload.wallet_address,
        payload.amount_wh,
        payload.price_wei_per_wh,
        tx_hash[:18] + "…",
        status,
    )

    return {
        "tx_hash": tx_hash,
        "status": status,
        "wallet_address": payload.wallet_address,
        "amount_wh": payload.amount_wh,
        "price_wei_per_wh": payload.price_wei_per_wh,
        "timestamp_ms": timestamp_ms,
    }


@app.post("/internal/emergency", status_code=200)
async def post_emergency_signal(
    x_internal_token: str = Header(default=""),
) -> dict:
    """Trigger emergency mode from the Python simulation runner.

    Called by energy/parallel_pulse/monad_bridge.py when a fault is detected.
    Broadcasts EmergencyActivated + CommunityUpdate to all WebSocket clients.
    """
    if x_internal_token != settings.internal_token:
        raise HTTPException(status_code=401, detail="Invalid internal token.")

    timestamp_ms = int(time.time() * 1000)

    # 1. Broadcast EmergencyActivated
    emergency_msg = EventMessage(
        event_type="EmergencyActivated",
        emergency_mode=True,
        timestamp_ms=timestamp_ms,
    )
    await _broadcast(emergency_msg.model_dump_json())

    # 2. Update community state
    community = get_community_state()
    community.activate_emergency()
    community_payload = community.build_event_payload()
    community_msg = EventMessage(**community_payload)
    await _broadcast(community_msg.model_dump_json())

    logger.info("Emergency activated via /internal/emergency")
    return {"status": "broadcast", "clients": len(connected_websockets)}
