from pydantic import BaseModel
from typing import Optional


class EventMessage(BaseModel):
    event_type: str  # "EmergencyActivated" | "TransferSettled" | "SOCUpdate" | "GridStatusUpdate"
    bus_id: Optional[int] = None
    bess_address: Optional[str] = None
    load_address: Optional[str] = None
    amount_wh: Optional[int] = None
    cost_wei: Optional[int] = None
    soc_percent: Optional[float] = None
    earnings_wei: Optional[int] = None
    emergency_mode: Optional[bool] = None
    timestamp_ms: int

    # --- Sprint 2: Grid topology fields (GridStatusUpdate) ----------------
    # List of bus IDs with failed upstream lines (e.g. [7] when feeder 6-7 is open).
    failed_buses: Optional[list[int]] = None
    # Pairs of (from_bus, to_bus) identifying the broken line segments.
    failed_lines: Optional[list[list[int]]] = None
    # BESS bus IDs currently injecting power into the grid.
    feeding_bess_buses: Optional[list[int]] = None
    # Energy flow vectors: [{"from_bus": int, "to_bus": int, "amount_wh": int}]
    feeding_flows: Optional[list[dict]] = None
    # str(bus_id) → soc_percent mapping for all known BESS units.
    bess_soc_map: Optional[dict[str, float]] = None


class BESSStateResponse(BaseModel):
    bess_address: str
    soc_percent: float
    earnings_wei: int
    emergency_mode: bool


class SOCUpdatePayload(BaseModel):
    bess_address: str
    soc_percent: float
    earnings_wei: int = 0
    timestamp_ms: Optional[int] = None
