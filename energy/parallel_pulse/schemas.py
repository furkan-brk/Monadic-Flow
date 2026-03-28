"""Canonical data schemas shared across all ParallelPulse layers.

These dataclasses define the fault signal structure that flows from
the Python simulation layer to the Monad smart contract and the
backend relay service.
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field


@dataclass
class FaultSignal:
    """Structured fault event emitted by IEEE33FaultDetector.

    This is the primary cross-layer data contract. Python constructs it;
    MonadBridge serialises it to a blockchain transaction.

    Attributes:
        bus_id: IEEE 33-bus node identifier (1–33).
        fault_type: One of "LINE_OPEN", "OVERLOAD", or "UNDERVOLTAGE".
        affected_loads: Human-readable names of loads impacted by the fault.
        timestamp_ms: Unix epoch time in milliseconds at fault detection.
        critical_load_ids: Names of critical loads (hospitals, schools) that
            need priority energy supply. These are mapped to deterministic
            Ethereum addresses by MonadBridge.
    """

    bus_id: int
    fault_type: str
    affected_loads: list[str]
    timestamp_ms: int
    critical_load_ids: list[str] = field(default_factory=list)

    @classmethod
    def line_open(
        cls,
        bus_id: int,
        affected_loads: list[str],
        critical_load_ids: list[str] | None = None,
    ) -> "FaultSignal":
        """Convenience constructor for a line-open fault event."""
        return cls(
            bus_id=bus_id,
            fault_type="LINE_OPEN",
            affected_loads=affected_loads,
            timestamp_ms=int(time.time() * 1000),
            critical_load_ids=critical_load_ids or [],
        )

    @classmethod
    def overload(
        cls,
        bus_id: int,
        affected_loads: list[str],
        critical_load_ids: list[str] | None = None,
    ) -> "FaultSignal":
        """Convenience constructor for an overload fault event."""
        return cls(
            bus_id=bus_id,
            fault_type="OVERLOAD",
            affected_loads=affected_loads,
            timestamp_ms=int(time.time() * 1000),
            critical_load_ids=critical_load_ids or [],
        )

    def to_dict(self) -> dict:
        """Serialise to a plain dict for HTTP payloads and logging."""
        return {
            "bus_id": self.bus_id,
            "fault_type": self.fault_type,
            "affected_loads": self.affected_loads,
            "timestamp_ms": self.timestamp_ms,
            "critical_load_ids": self.critical_load_ids,
        }


@dataclass
class SOCReading:
    """State-of-charge reading emitted by a BESS device each market cycle.

    Sent by runner.py to the backend /internal/soc endpoint so Flutter
    clients receive live SOC updates without querying the chain.
    """

    bess_address: str
    soc_percent: float
    earnings_wei: int
    timestamp_ms: int = field(default_factory=lambda: int(time.time() * 1000))

    def to_dict(self) -> dict:
        return {
            "bess_address": self.bess_address,
            "soc_percent": round(self.soc_percent, 2),
            "earnings_wei": self.earnings_wei,
            "timestamp_ms": self.timestamp_ms,
        }
