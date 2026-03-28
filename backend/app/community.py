"""community.py — In-memory Energy Community state aggregator.

Tracks cumulative transfer statistics across the lifetime of the backend
process. Data is lost on restart (no persistence layer in MVP).

Usage::

    from .community import get_community_state

    # Record a settled transfer (called from chain_listener.py):
    get_community_state().record_transfer(
        bess_address="0xABC…",
        load_address="0xDEF…",
        amount_wh=5000,
        earnings_wei=1_500_000_000_000_000,
    )

    # Build a CommunityUpdate WebSocket event payload:
    payload = get_community_state().build_event_payload()
"""

from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Any


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------


@dataclass
class LeaderboardEntry:
    address: str
    earnings_wei: int = 0
    total_energy_wh: int = 0

    @property
    def rank(self) -> int:
        """Rank is set externally when building the sorted list."""
        return 0  # Overridden by CommunityState.sorted_leaderboard()


@dataclass
class RecentTransfer:
    bess_address: str
    load_address: str
    amount_wh: int
    earnings_wei: int
    timestamp_ms: int

    def to_dict(self) -> dict[str, Any]:
        return {
            "bess_address": self.bess_address,
            "load_address": self.load_address,
            "amount_wh": self.amount_wh,
            "earnings_wei": self.earnings_wei,
            "timestamp_ms": self.timestamp_ms,
        }


# ---------------------------------------------------------------------------
# Community state singleton
# ---------------------------------------------------------------------------


class CommunityState:
    """Thread-unsafe in-memory state accumulator.

    All mutations happen in the asyncio event loop so no locking is required.
    """

    _MAX_RECENT = 50  # Number of recent transfers to keep in memory.

    def __init__(self) -> None:
        self.total_energy_wh: int = 0
        self.settlement_count: int = 0
        self._by_address: dict[str, LeaderboardEntry] = {}
        self._recent: list[RecentTransfer] = []
        self.is_emergency: bool = False

    # ------------------------------------------------------------------
    # Mutation helpers
    # ------------------------------------------------------------------

    def record_transfer(
        self,
        bess_address: str,
        load_address: str,
        amount_wh: int,
        earnings_wei: int,
    ) -> None:
        """Accumulate a settled transfer into community statistics."""
        self.total_energy_wh += amount_wh
        self.settlement_count += 1

        # Update / create leaderboard entry.
        if bess_address not in self._by_address:
            self._by_address[bess_address] = LeaderboardEntry(address=bess_address)
        entry = self._by_address[bess_address]
        entry.earnings_wei += earnings_wei
        entry.total_energy_wh += amount_wh

        # Prepend recent transfer; cap list size.
        self._recent.insert(
            0,
            RecentTransfer(
                bess_address=bess_address,
                load_address=load_address,
                amount_wh=amount_wh,
                earnings_wei=earnings_wei,
                timestamp_ms=int(time.time() * 1000),
            ),
        )
        if len(self._recent) > self._MAX_RECENT:
            self._recent.pop()

    def activate_emergency(self) -> None:
        """Mark community as being in emergency mode."""
        self.is_emergency = True

    # ------------------------------------------------------------------
    # Read helpers
    # ------------------------------------------------------------------

    @property
    def active_bess_count(self) -> int:
        return len(self._by_address)

    def sorted_leaderboard(self) -> list[dict[str, Any]]:
        """Return leaderboard sorted by earnings (descending), with rank field."""
        entries = sorted(
            self._by_address.values(),
            key=lambda e: e.earnings_wei,
            reverse=True,
        )
        return [
            {
                "address": e.address,
                "earnings_wei": e.earnings_wei,
                "total_energy_wh": e.total_energy_wh,
                "rank": rank + 1,
            }
            for rank, e in enumerate(entries)
        ]

    def recent_transfers(self, limit: int = 10) -> list[dict[str, Any]]:
        return [t.to_dict() for t in self._recent[:limit]]

    # ------------------------------------------------------------------
    # Event payload builder
    # ------------------------------------------------------------------

    def build_event_payload(self) -> dict[str, Any]:
        """Build a CommunityUpdate EventMessage-compatible dict."""
        return {
            "event_type": "CommunityUpdate",
            "timestamp_ms": int(time.time() * 1000),
            "community_total_energy_wh": self.total_energy_wh,
            "community_active_bess_count": self.active_bess_count,
            "community_settlement_count": self.settlement_count,
            "community_is_emergency": self.is_emergency,
            "community_leaderboard": self.sorted_leaderboard(),
            "community_recent_transfers": self.recent_transfers(limit=5),
        }

    def to_stats_dict(self) -> dict[str, Any]:
        """Serialise full community stats for the REST endpoint."""
        return {
            "total_energy_wh": self.total_energy_wh,
            "active_bess_count": self.active_bess_count,
            "settlement_count": self.settlement_count,
            "is_emergency": self.is_emergency,
        }


# ---------------------------------------------------------------------------
# Module-level singleton (shared across main.py and chain_listener.py)
# ---------------------------------------------------------------------------

_community = CommunityState()


def get_community_state() -> CommunityState:
    """Return the module-level [CommunityState] singleton."""
    return _community
