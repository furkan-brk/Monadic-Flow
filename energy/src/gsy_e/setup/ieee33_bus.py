"""IEEE 33-Bus Test Feeder setup for ParallelPulse.

Models the standard IEEE 33-bus radial distribution network as a gsy-e
Area/Market/Asset tree. The topology is approximated as a hierarchical
market structure (not a full power-flow model) for the hackathon scope.

Bus hierarchy (simplified):
    Substation (bus 1)
    ├── Feeder A — buses 2–18  (main trunk)
    │   ├── Lateral A1 — buses 19–22
    │   └── Lateral A2 — buses 23–25
    └── Feeder B — buses 26–33  (branch)

Critical loads (hospitals, schools) are placed at buses 6, 9, 17, 25.
Two BESS devices (BESSEmergencyStrategy) are placed at buses 12 and 22
for maximum coverage of both feeders.

Usage:
    gsy-e run --setup ieee33_bus -t 15s -d 2h --no-export

Reference:
    https://www.researchgate.net/figure/and-Fig-2-show-the-base-configurations-
    for-IEEE-33-and-IEEE-69-bus-systems_fig1_328176142
"""
from __future__ import annotations

from gsy_e.models.area import Area  # type: ignore[import]
from gsy_e.models.leaves import Market  # type: ignore[import]  # noqa: F401  (re-export alias)
from gsy_e.models.strategy.load_hours import LoadHoursStrategy  # type: ignore[import]
from gsy_e.models.strategy.commercial_producer import CommercialStrategy  # type: ignore[import]
from gsy_e.models.strategy.pv import PVStrategy  # type: ignore[import]

# Import ParallelPulse BESS strategy (sibling package within energy/)
try:
    from gsy_e.models.strategy.bess_emergency_strategy import (  # type: ignore[import]
        BESSEmergencyStrategy,
    )
except ImportError:
    # Fallback: use plain StorageStrategy if custom strategy is not yet installed
    from gsy_e.models.strategy.storage import StorageStrategy as BESSEmergencyStrategy  # type: ignore[import]  # noqa: E501

# ---------------------------------------------------------------------------
# Bus parameters — avg_power_W values represent normalised IEEE 33-bus loads
# ---------------------------------------------------------------------------
_LOAD_MW = {
    2: 100, 3: 90, 4: 120, 5: 60, 6: 60,    # critical: Hospital_Bus6
    7: 200, 8: 200, 9: 60,                    # critical: School_Bus9
    10: 60, 11: 45, 12: 60, 13: 60, 14: 120,
    15: 60, 16: 60, 17: 60,                   # critical: Hospital_Bus17
    18: 90, 19: 90, 20: 90, 21: 90, 22: 90,
    23: 90, 24: 420, 25: 420,                 # critical: School_Bus25
    26: 60, 27: 60, 28: 60, 29: 120, 30: 200,
    31: 150, 32: 210, 33: 60,
}

# Buses carrying critical loads
_CRITICAL_BUSES: set[int] = {6, 9, 17, 25}

# Selling rate for normal loads (cents/kWh)
_NORMAL_BUYING_RATE: float = 21.0
# Critical loads bid higher to ensure supply priority
_CRITICAL_BUYING_RATE: float = 35.0

# BESS parameters
_BESS_CAPACITY_KWH: float = 500.0
_BESS_MAX_POWER_KW: float = 100.0
_BESS_INITIAL_SOC: float = 80.0    # Start at 80% for demo


def _make_load(bus_id: int) -> Area:
    """Create a load Asset for a given IEEE 33-bus node."""
    power_w = _LOAD_MW[bus_id] * 1000  # convert to Watts for gsy-e
    is_critical = bus_id in _CRITICAL_BUSES
    prefix = "Hospital" if bus_id in {6, 17} else ("School" if bus_id in {9, 25} else "Load")
    name = f"{prefix}_Bus{bus_id}"
    rate = _CRITICAL_BUYING_RATE if is_critical else _NORMAL_BUYING_RATE

    return Area(
        name,
        strategy=LoadHoursStrategy(
            avg_power_W=power_w,
            hrs_of_day=list(range(24)),
            final_buying_rate=rate,
        ),
    )


def _make_bess(bus_id: int, label: str = "BESS") -> Area:
    """Create a BESS Asset (BESSEmergencyStrategy) for the given bus."""
    return Area(
        f"{label}_Bus{bus_id}",
        strategy=BESSEmergencyStrategy(
            battery_capacity_kWh=_BESS_CAPACITY_KWH,
            max_abs_battery_power_kW=_BESS_MAX_POWER_KW,
            initial_soc=_BESS_INITIAL_SOC,
            final_selling_rate=25.0,
            final_buying_rate=10.0,
        ),
    )


def _make_pv(bus_id: int, panels: int = 10) -> Area:
    """Create a small rooftop PV asset near a bus."""
    return Area(
        f"PV_Bus{bus_id}",
        strategy=PVStrategy(panel_count=panels, final_selling_rate=5.0),
    )


def get_setup(config):  # noqa: ANN001
    """Build and return the IEEE 33-bus Area tree.

    This is the standard gsy-e setup module entry point.
    gsy-e calls `get_setup(config)` at simulation start.

    Args:
        config: SimulationConfig provided by the simulation runner.

    Returns:
        Root Area representing the substation grid.
    """
    config.set_market_maker_rate(30)

    # ---------------------------------------------------------------
    # Feeder A — buses 2-18 (main trunk)
    # ---------------------------------------------------------------
    lateral_a1 = Area(
        "Lateral_A1_Bus19-22",
        [
            _make_load(19), _make_load(20), _make_load(21), _make_load(22),
            _make_bess(22, label="BESS_A"),   # BESS at bus 22 covers lateral A1
        ],
    )

    lateral_a2 = Area(
        "Lateral_A2_Bus23-25",
        [_make_load(23), _make_load(24), _make_load(25)],  # School_Bus25 here
    )

    feeder_a = Area(
        "Feeder_A_Bus2-18",
        [
            _make_load(2),
            _make_load(3),
            _make_load(4),
            _make_load(5),
            _make_load(6),   # Hospital_Bus6 — critical
            _make_pv(6, panels=8),
            _make_load(7),
            _make_load(8),
            _make_load(9),   # School_Bus9 — critical
            _make_load(10),
            _make_load(11),
            _make_load(12),
            _make_bess(12, label="BESS_B"),  # BESS at bus 12 covers trunk
            _make_load(13),
            _make_load(14),
            _make_load(15),
            _make_load(16),
            _make_load(17),  # Hospital_Bus17 — critical
            _make_pv(17, panels=6),
            _make_load(18),
            lateral_a1,
            lateral_a2,
        ],
    )

    # ---------------------------------------------------------------
    # Feeder B — buses 26-33 (branch feeder)
    # ---------------------------------------------------------------
    feeder_b = Area(
        "Feeder_B_Bus26-33",
        [
            _make_load(26),
            _make_load(27),
            _make_load(28),
            _make_load(29),
            _make_load(30),
            _make_load(31),
            _make_load(32),
            _make_load(33),
        ],
    )

    # ---------------------------------------------------------------
    # Root: Substation (bus 1)
    # ---------------------------------------------------------------
    grid = Area(
        "IEEE33_Substation",
        [
            Area(
                "Main_Grid_Supply",
                strategy=CommercialStrategy(energy_rate=30),
            ),
            feeder_a,
            feeder_b,
        ],
        config=config,
    )

    return grid
