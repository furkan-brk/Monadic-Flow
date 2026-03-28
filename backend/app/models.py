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

    # --- Sprint 3: Community aggregation fields (CommunityUpdate) ---------
    # Total energy contributed across all BESS in this session (Wh).
    community_total_energy_wh: Optional[int] = None
    # Number of distinct BESS addresses that have contributed this session.
    community_active_bess_count: Optional[int] = None
    # Total number of settled transfers.
    community_settlement_count: Optional[int] = None
    # True when grid is in emergency mode.
    community_is_emergency: Optional[bool] = None
    # Top BESS providers sorted by earnings: [{address, earnings_wei,
    # total_energy_wh, rank}]
    community_leaderboard: Optional[list[dict]] = None
    # 5 most recent settled transfers.
    community_recent_transfers: Optional[list[dict]] = None


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


class OfferPayload(BaseModel):
    """Body for POST /bess/offer — submitted by BESS owners during emergency."""
    wallet_address: str
    amount_wh: int
    price_wei_per_wh: int = 5
