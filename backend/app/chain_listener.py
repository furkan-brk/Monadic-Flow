import asyncio
import logging
import time
from typing import Any, Callable, Coroutine

from web3 import Web3

logger = logging.getLogger(__name__)

MINIMAL_ABI = [
    {
        "type": "event",
        "name": "EmergencyActivated",
        "inputs": [
            {"name": "busId", "type": "uint256", "indexed": True},
            {"name": "criticalLoads", "type": "address[]", "indexed": False},
            {"name": "timestamp", "type": "uint256", "indexed": False},
        ],
    },
    {
        "type": "event",
        "name": "TransferSettled",
        "inputs": [
            {"name": "bess", "type": "address", "indexed": True},
            {"name": "load", "type": "address", "indexed": True},
            {"name": "amount", "type": "uint256", "indexed": False},
            {"name": "cost", "type": "uint256", "indexed": False},
        ],
    },
    {
        "type": "function",
        "name": "emergencyMode",
        "inputs": [],
        "outputs": [{"type": "bool"}],
        "stateMutability": "view",
    },
    {
        "type": "function",
        "name": "earnings",
        "inputs": [{"name": "", "type": "address"}],
        "outputs": [{"type": "uint256"}],
        "stateMutability": "view",
    },
    {
        "type": "function",
        "name": "offerAmount",
        "inputs": [{"name": "", "type": "address"}],
        "outputs": [{"type": "uint256"}],
        "stateMutability": "view",
    },
]


class ChainEventListener:
    """Polls the Monad chain for EmergencyActivated and TransferSettled events
    and broadcasts them (plus a GridStatusUpdate) to all connected WebSocket
    clients via broadcast_fn."""

    def __init__(
        self,
        web3: Web3,
        contract: Any,
        broadcast_fn: Callable[[str], Coroutine],
        soc_getter: Callable[[], dict[int, float]] | None = None,
    ) -> None:
        self._w3 = web3
        self._contract = contract
        self._broadcast = broadcast_fn
        # Callable that returns current {bus_id: soc_percent} dict from main.py.
        self._soc_getter = soc_getter or (lambda: {})

    # ------------------------------------------------------------------
    # Public
    # ------------------------------------------------------------------

    async def listen_loop(self) -> None:
        """Main polling loop. Creates event filters then polls every second."""
        loop = asyncio.get_event_loop()

        emergency_filter = None
        transfer_filter = None

        # Create filters — if the RPC does not support eth_newFilter we catch
        # the error once and fall back to no-op (simulated / local setups).
        try:
            emergency_filter = await loop.run_in_executor(
                None,
                self._contract.events.EmergencyActivated.create_filter,
                {"fromBlock": "latest"},
            )
            transfer_filter = await loop.run_in_executor(
                None,
                self._contract.events.TransferSettled.create_filter,
                {"fromBlock": "latest"},
            )
            logger.info("Chain event filters created successfully.")
        except Exception as exc:
            logger.warning(
                "Could not create chain event filters (%s). "
                "Chain listener will be inactive — /internal/soc relay still works.",
                exc,
            )
            return

        logger.info("ChainEventListener polling started.")
        while True:
            await asyncio.sleep(1.0)
            await self._poll_filter(loop, emergency_filter, self._handle_emergency)
            await self._poll_filter(loop, transfer_filter, self._handle_transfer)

    # ------------------------------------------------------------------
    # Private helpers
    # ------------------------------------------------------------------

    async def _poll_filter(
        self,
        loop: asyncio.AbstractEventLoop,
        event_filter: Any,
        handler: Callable,
    ) -> None:
        """Fetch new entries from *event_filter* and pass each to *handler*."""
        try:
            entries = await loop.run_in_executor(None, event_filter.get_new_entries)
        except Exception as exc:
            logger.warning("Error fetching filter entries: %s", exc)
            return

        for entry in entries:
            try:
                await handler(entry)
            except Exception as exc:
                logger.warning("Error processing chain event entry: %s", exc)

    async def _handle_emergency(self, entry: dict) -> None:
        """Process EmergencyActivated log: broadcast primary event + GridStatusUpdate."""
        from .models import EventMessage
        from .grid_topology import build_grid_status_update

        args = entry.get("args", {})
        bus_id = int(args.get("busId", 0))
        timestamp_val = int(args.get("timestamp", 0))
        timestamp_ms = timestamp_val * 1000 if timestamp_val < 1e12 else timestamp_val

        # 1. Primary EmergencyActivated event
        primary = EventMessage(
            event_type="EmergencyActivated",
            bus_id=bus_id,
            emergency_mode=True,
            timestamp_ms=timestamp_ms,
        )
        await self._broadcast(primary.model_dump_json())
        logger.info("EmergencyActivated → bus_id=%d", bus_id)

        # 2. GridStatusUpdate — marks the failed line on the topology map
        grid_payload = build_grid_status_update(
            failed_bus_id=bus_id,
            bess_soc_map=self._soc_getter(),
        )
        grid_msg = EventMessage(**grid_payload)
        await self._broadcast(grid_msg.model_dump_json())
        logger.info("GridStatusUpdate emitted for EmergencyActivated bus_id=%d", bus_id)

    async def _handle_transfer(self, entry: dict) -> None:
        """Process TransferSettled log: broadcast primary event + GridStatusUpdate."""
        from .models import EventMessage
        from .config import settings
        from .grid_topology import build_grid_status_update, bess_address_to_bus

        args = entry.get("args", {})
        bess_address: str | None = args.get("bess")
        load_address: str | None = args.get("load")
        amount_wh = int(args.get("amount", 0))
        cost_wei = int(args.get("cost", 0))
        timestamp_ms = int(time.time() * 1000)

        # 1. Primary TransferSettled event
        primary = EventMessage(
            event_type="TransferSettled",
            bess_address=bess_address,
            load_address=load_address,
            amount_wh=amount_wh,
            cost_wei=cost_wei,
            timestamp_ms=timestamp_ms,
        )
        await self._broadcast(primary.model_dump_json())
        logger.info(
            "TransferSettled bess=%s load=%s amount=%d Wh cost=%d wei",
            bess_address, load_address, amount_wh, cost_wei,
        )

        # 2. GridStatusUpdate — highlight BESS bus that is actively feeding
        bess_bus = bess_address_to_bus(
            bess_address or "",
            settings.bess_a_address,
            settings.bess_b_address,
        )
        grid_payload = build_grid_status_update(
            settled_bess_bus=bess_bus,
            settled_load_bus=None,   # address-to-bus reverse lookup is non-trivial
            settled_amount_wh=amount_wh if bess_bus else None,
            bess_soc_map=self._soc_getter(),
        )
        grid_msg = EventMessage(**grid_payload)
        await self._broadcast(grid_msg.model_dump_json())
        logger.info("GridStatusUpdate emitted for TransferSettled bess_bus=%s", bess_bus)
