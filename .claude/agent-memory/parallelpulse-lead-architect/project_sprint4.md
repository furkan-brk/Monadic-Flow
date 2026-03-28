---
name: Sprint 4 Singularity Map Integration
description: Geo-map tab, community settings, savings KPI, trade profile chart — Singularity Map feature parity
type: project
---

Sprint 4 adds full Grid Singularity Singularity Map feature parity to the Flutter app.

**Why:** User wants to use Singularity Map features (geo-tagged assets, community settings, savings KPI, trade profiles) natively within ParallelPulse — not as an external web link.

**New packages added:**
- `flutter_map: ^7.0.2` — OpenStreetMap tiles, no API key needed
- `latlong2: ^0.9.1` — LatLng coordinates required by flutter_map

**New files:**
- `client/lib/features/map/models/bus_geo_data.dart` — IEEE 33-bus geo coords (Kadıköy, Istanbul center) + line topology list
- `client/lib/features/map/singularity_map_screen.dart` — 4th tab "Harita"; flutter_map + OSM tiles, PolylineLayer for grid lines (red=fault, indigo=normal), MarkerLayer with pulse animation for islanded/feeding nodes, bottom sheet on tap with Turkish labels
- `client/lib/features/settings/community_settings_screen.dart` — Market settings: type (one_sided/two_sided_bid/two_sided_clear), fee type+value, slot length, tick length, sim days. Persisted via SharedPreferences keys: pp_market_type, pp_fee_type, pp_fee_value, pp_slot_len, pp_tick_len, pp_sim_days
- `client/lib/features/community/widgets/savings_kpi_card.dart` — 2×2 KPI grid: Şebeke Tasarrufu (EUR), Öz-Yeterlilik (%), CO₂ Tasarrufu (kg), MON Kazanım (mMON). Derived from CommunitySnapshot.
- `client/lib/features/community/widgets/trade_profile_chart.dart` — Pure CustomPainter line chart (no fl_chart), shows last 10 time slots, filled indigo gradient, red emergency spike at T-0, volume bars

**Modified files:**
- `client/lib/main.dart` — SingularityMapScreen at _screens[3], 4th NavigationDestination "Harita" with _MapTabIcon (red badge via Consumer<GridTopologyNotifier>)
- `client/lib/features/community/community_screen.dart` — Settings icon in AppBar → Navigator.push CommunitySettingsScreen; SavingsKpiCard + TradeProfileChart inserted between CommunityStatsHeader and MyWalletCard

**Geo coordinate layout:**
- Center: LatLng(40.9920, 29.0640), zoom 13.5
- Main feeder Bus 1-18: east-west at lat 40.9920, lng 29.0100→29.1120
- Branch A (Bus 19-22): south at lat 40.9870
- Branch B (Bus 23-25): north at lat 40.9970
- Branch C (Bus 26-33): south (40.9850) then east (40.9810)

**How to apply:** When adding map features or analytics widgets, follow flutter_map + custom painter patterns. Settings always persist to SharedPreferences with `pp_` prefix. TradeProfileChart uses no external chart library — keep it that way to minimize dependencies.
