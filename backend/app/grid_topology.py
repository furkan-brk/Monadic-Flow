"""Static IEEE 33-bus topology knowledge for the ParallelPulse backend.

This module contains:
- Bus type classifications (critical loads, BESS, substation, normal)
- Line adjacency list for the IEEE 33-bus test feeder
- Fault-line mapping: bus_id → (from_bus, to_bus) upstream line
- Load name → bus ID mapping (mirrors fault_detector.py)
- Helper functions to build GridStatusUpdate EventMessage payloads
"""
from __future__ import annotations

import os
import time

# ---------------------------------------------------------------------------
# Static topology data
# ---------------------------------------------------------------------------

BUS_TYPES: dict[int, str] = {
    1: "SUBSTATION",
    6: "CRITICAL_L1",   # Hospital_Bus6
    9: "CRITICAL_L2",   # School_Bus9
    12: "BESS",         # BESS_B
    17: "CRITICAL_L1",  # Hospital_Bus17
    22: "BESS",         # BESS_A
    25: "CRITICAL_L2",  # School_Bus25
}

# Full 33-bus radial topology adjacency list (from_bus, to_bus).
# Main trunk: 1-18, Lateral A1: 2→19-22, Lateral A2: 3→23-25,
# Lateral B: 6→26-33.
ADJACENCY: list[tuple[int, int]] = [
    (1, 2), (2, 3), (3, 4), (4, 5), (5, 6), (6, 7), (7, 8), (8, 9), (9, 10),
    (10, 11), (11, 12), (12, 13), (13, 14), (14, 15), (15, 16), (16, 17), (17, 18),
    (2, 19), (19, 20), (20, 21), (21, 22),
    (3, 23), (23, 24), (24, 25),
    (6, 26), (26, 27), (27, 28), (28, 29), (29, 30), (30, 31), (31, 32), (32, 33),
]

# Fault injection bus → upstream line that disconnects when this bus faults.
# Mirrors fault_detector.py FAULT_BUS_SEQUENCE = [33, 28, 18, 12, 7].
FAULT_LINE_MAP: dict[int, tuple[int, int]] = {
    7: (6, 7),
    12: (11, 12),
    18: (17, 18),
    28: (27, 28),
    33: (32, 33),
}

# Human-readable load name → bus ID mapping (mirrors fault_detector.py).
LOAD_BUS_MAP: dict[str, int] = {
    "Hospital_Bus6": 6,
    "School_Bus9": 9,
    "Hospital_Bus17": 17,
    "School_Bus25": 25,
}

# ---------------------------------------------------------------------------
# Address resolution helpers
# ---------------------------------------------------------------------------


def bess_address_to_bus(address: str, bess_a_addr: str, bess_b_addr: str) -> int | None:
    """Map a BESS Ethereum address → bus ID.

    Args:
        address:     The address to look up (case-insensitive).
        bess_a_addr: Configured address for BESS_A (Bus 22).
        bess_b_addr: Configured address for BESS_B (Bus 12).

    Returns:
        Bus ID (22 or 12) or None if the address is not recognised.
    """
    addr = (address or "").lower().strip()
    if addr and addr == bess_a_addr.lower().strip():
        return 22
    if addr and addr == bess_b_addr.lower().strip():
        return 12
    return None


# ---------------------------------------------------------------------------
# GridStatusUpdate payload builder
# ---------------------------------------------------------------------------


def build_grid_status_update(
    *,
    failed_bus_id: int | None = None,
    settled_bess_bus: int | None = None,
    settled_load_bus: int | None = None,
    settled_amount_wh: int | None = None,
    bess_soc_map: dict[int, float] | None = None,
) -> dict:
    """Construct a GridStatusUpdate EventMessage payload dict.

    All parameters are optional; omit those not relevant to the trigger event.

    Returns a flat dict matching the EventMessage Pydantic model, ready for
    ``EventMessage(**result).model_dump_json()``.
    """
    failed_buses: list[int] = []
    failed_lines: list[list[int]] = []

    if failed_bus_id is not None and failed_bus_id in FAULT_LINE_MAP:
        failed_buses.append(failed_bus_id)
        a, b = FAULT_LINE_MAP[failed_bus_id]
        failed_lines.append([a, b])

    feeding_flows: list[dict] = []
    feeding_bess_buses: list[int] = []

    if settled_bess_bus is not None and settled_amount_wh is not None:
        feeding_bess_buses.append(settled_bess_bus)
        if settled_load_bus is not None:
            feeding_flows.append({
                "from_bus": settled_bess_bus,
                "to_bus": settled_load_bus,
                "amount_wh": settled_amount_wh,
            })

    soc_payload: dict[str, float] | None = None
    if bess_soc_map:
        soc_payload = {str(k): v for k, v in bess_soc_map.items()}

    return {
        "event_type": "GridStatusUpdate",
        "timestamp_ms": int(time.time() * 1000),
        "failed_buses": failed_buses if failed_buses else None,
        "failed_lines": failed_lines if failed_lines else None,
        "feeding_bess_buses": feeding_bess_buses if feeding_bess_buses else None,
        "feeding_flows": feeding_flows if feeding_flows else None,
        "bess_soc_map": soc_payload,
    }
