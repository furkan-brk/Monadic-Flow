"""BESS Emergency Strategy for ParallelPulse.

Extends gsy-e's StorageStrategy with:
- Emergency mode price multiplier (5×) for high-reward periods.
- SOC exposure via get_soc_percent() for the backend SOC relay.
- Earnings tracking across market cycles.

Platform note: Must run on Linux/macOS/WSL2 (not native Windows).
Line length: ≤ 99 characters (flake8/black compliant).
"""
from __future__ import annotations

import logging
from typing import TYPE_CHECKING

from gsy_e.models.strategy.storage import StorageStrategy  # type: ignore[import]

if TYPE_CHECKING:
    pass  # noqa: F401

logger = logging.getLogger(__name__)

# Default emergency price multiplier — must match EMERGENCY_MULTIPLIER in EnergyMarket.sol.
DEFAULT_EMERGENCY_MULTIPLIER: float = 5.0

# Minimum SOC (%) below which the BESS will not sell (protect battery health).
_MIN_SELL_SOC_PCT: float = 15.0


class BESSEmergencyStrategy(StorageStrategy):
    """StorageStrategy extension for ParallelPulse emergency response.

    During normal operation this strategy behaves identically to
    StorageStrategy.  When emergency_mode is set to True (triggered by
    MonadBridge receiving an EmergencyActivated event), the effective
    selling rate is multiplied by emergency_price_multiplier, incentivising
    BESS owners to dispatch energy to critical loads.

    Args:
        emergency_price_multiplier: Selling rate multiplier in emergency mode.
        All other args are forwarded to StorageStrategy.
    """

    def __init__(
        self,
        *,
        emergency_price_multiplier: float = DEFAULT_EMERGENCY_MULTIPLIER,
        **kwargs,
    ) -> None:
        super().__init__(**kwargs)
        self.emergency_mode: bool = False
        self.emergency_price_multiplier: float = emergency_price_multiplier
        self._accumulated_earnings_kwh: float = 0.0
        self._base_final_selling_rate: float = kwargs.get("final_selling_rate", 25.0)

    # ------------------------------------------------------------------
    # Public API used by ParallelPulse
    # ------------------------------------------------------------------

    def activate_emergency(self) -> None:
        """Enable emergency pricing — call when EmergencyActivated event received."""
        if not self.emergency_mode:
            self.emergency_mode = True
            self._apply_emergency_rates()
            logger.info(
                "%s emergency mode ACTIVATED. Selling rate ×%.0f",
                self.owner.name if self.owner else "BESS",
                self.emergency_price_multiplier,
            )

    def deactivate_emergency(self) -> None:
        """Disable emergency pricing — call when EmergencyDeactivated event received."""
        if self.emergency_mode:
            self.emergency_mode = False
            self._restore_normal_rates()
            logger.info(
                "%s emergency mode DEACTIVATED.",
                self.owner.name if self.owner else "BESS",
            )

    def get_soc_percent(self) -> float:
        """Return current SOC as a percentage (0–100).

        Returns:
            SOC percentage clamped to [0, 100].
        """
        try:
            if self.state.capacity <= 0:
                return 0.0
            raw = self.state.used_storage / self.state.capacity * 100.0
            return max(0.0, min(100.0, raw))
        except AttributeError:
            # state not yet initialised (before first market cycle)
            return float(getattr(self, "_initial_soc", 80.0))

    def get_accumulated_earnings_kwh(self) -> float:
        """Return total energy traded (kWh) since simulation start."""
        return self._accumulated_earnings_kwh

    # ------------------------------------------------------------------
    # gsy-e lifecycle hooks
    # ------------------------------------------------------------------

    def event_market_cycle(self) -> None:
        """Override: apply emergency pricing before posting offers."""
        if self.emergency_mode:
            # Guard: don't sell below minimum SOC
            if self.get_soc_percent() <= _MIN_SELL_SOC_PCT:
                logger.debug(
                    "%s SOC %.1f%% ≤ min %.1f%% — skipping emergency offer.",
                    self.owner.name if self.owner else "BESS",
                    self.get_soc_percent(),
                    _MIN_SELL_SOC_PCT,
                )
                return
            self._apply_emergency_rates()
        else:
            self._restore_normal_rates()
        super().event_market_cycle()

    def event_offer_traded(self, *, market_id, trade) -> None:  # noqa: ANN001
        """Track accumulated energy sold."""
        try:
            self._accumulated_earnings_kwh += float(trade.offer.energy)
        except (AttributeError, TypeError):
            pass
        super().event_offer_traded(market_id=market_id, trade=trade)

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _apply_emergency_rates(self) -> None:
        """Multiply effective selling rate by emergency_price_multiplier."""
        new_rate = self._base_final_selling_rate * self.emergency_price_multiplier
        # gsy-e StorageStrategy uses offer_update to manage rates
        if hasattr(self, "offer_update") and hasattr(self.offer_update, "final_rate"):
            self.offer_update.final_rate = new_rate
        # Also update the direct attribute used by some gsy-e versions
        if hasattr(self, "final_selling_rate"):
            self.final_selling_rate = new_rate

    def _restore_normal_rates(self) -> None:
        """Restore selling rate to the base (non-emergency) value."""
        if hasattr(self, "offer_update") and hasattr(self.offer_update, "final_rate"):
            self.offer_update.final_rate = self._base_final_selling_rate
        if hasattr(self, "final_selling_rate"):
            self.final_selling_rate = self._base_final_selling_rate
