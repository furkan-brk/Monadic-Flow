---
name: Sprint 3 Wallet Auth + Energy Community Hub
description: Sprint 3 IMPLEMENTED — wallet auth gate, Community as main tab, CommunityUpdate WebSocket event, community REST endpoints, leaderboard
type: project
---

Sprint 3 adds **wallet authentication** and makes the **Energy Community** screen the primary feature of ParallelPulse.

**Why:** BESS owners need identity to submit on-chain offers and see peer activity. Community is the "social proof" main feature for the hackathon demo.

## Auth Gate

`WalletStateNotifier` (SharedPreferences) → `Consumer<WalletStateNotifier>` in `MaterialApp.home`:
- `address == null` → `WalletConnectScreen` (full-screen onboarding)
- `address != null` → `AppShell` (3-tab BottomNav)

Two connect modes: manual 0x address paste (clipboard button), or "Demo Mode" (random secure hex address). `main()` is async; `loadPersistedSession()` awaited before `runApp` to avoid auth flash.

## New Tab Order (AppShell)

| Index | Label | Screen | Notifier |
|-------|-------|---------|----------|
| 0 | Topluluk ⭐ | CommunityScreen | CommunityStateNotifier |
| 1 | Panel | DashboardScreen | BESSStateNotifier |
| 2 | Şebeke | GridTopologyScreen | GridTopologyNotifier |

Community is the default landing tab (index 0) after login.

## New Files (Sprint 3)

| File | Purpose |
|------|---------|
| `client/lib/core/models/wallet_state.dart` | WalletState + WalletStateNotifier; SharedPreferences; Demo mode |
| `client/lib/core/models/community_state.dart` | CommunitySnapshot + CommunityStateNotifier; accumulates TransferSettled |
| `client/lib/features/auth/wallet_connect_screen.dart` | Login screen: address paste + demo mode; branding header |
| `client/lib/features/community/community_screen.dart` | Main hub: SliverAppBar + stats + my wallet + leaderboard + feed |
| `client/lib/features/community/widgets/community_stats_header.dart` | Live aggregate card with PulseDot animation |
| `client/lib/features/community/widgets/bess_leaderboard.dart` | Top-5 BESS with 🥇🥈🥉 medals; "BEN" badge for connected wallet |
| `client/lib/features/community/widgets/my_wallet_card.dart` | SOC/earnings mini stats + Teklif Ver CTA (gated on emergencyMode) |
| `client/lib/features/community/widgets/transfer_feed_tile.dart` | Single transfer row: BESS→Load chip, amount, earnings, time-ago |
| `backend/app/community.py` | CommunityState singleton: record_transfer, activate_emergency, build_event_payload, REST serialisers |

## Modified Files (Sprint 3)

| File | Change |
|------|--------|
| `client/pubspec.yaml` | Added `shared_preferences: ^2.3.4` |
| `client/lib/main.dart` | async main + all 4 notifiers + auth gate Consumer + 3-tab AppShell; Community badge on emergency |
| `client/lib/features/dashboard/dashboard_screen.dart` | Wallet chip in AppBar + disconnect dialog |
| `client/lib/core/models/event_message.dart` | 6 new community fields for CommunityUpdate event |
| `backend/app/models.py` | 6 new community fields in EventMessage Pydantic model |
| `backend/app/chain_listener.py` | Emits CommunityUpdate after EmergencyActivated and TransferSettled |
| `backend/app/main.py` | Import community; /community/stats, /community/leaderboard, /community/feed, /internal/emergency |

## New WebSocket Event: CommunityUpdate

```json
{
  "event_type": "CommunityUpdate",
  "timestamp_ms": 1711600000000,
  "community_total_energy_wh": 15000,
  "community_active_bess_count": 2,
  "community_settlement_count": 7,
  "community_is_emergency": true,
  "community_leaderboard": [
    {"address": "0xABC...", "earnings_wei": 1500000000000000, "total_energy_wh": 8000, "rank": 1}
  ],
  "community_recent_transfers": [...]
}
```

## New Backend REST Endpoints

- `GET /community/stats` — aggregate session stats
- `GET /community/leaderboard` — sorted BESS earnings list
- `GET /community/feed?limit=20` — recent transfers
- `POST /internal/emergency` — trigger emergency from simulation (no chain listener needed)

## Key Design Decisions

- **No web3dart in MVP** — address is display-only; server signs all TXs via web3.py.
- **Submit Offer CTA** — gated on `BESSStateNotifier.emergencyMode`; shows demo confirmation in MVP.
- **CommunityStateNotifier does NOT call ws.connect()** — BESSStateNotifier still owns connection.
- **Leaderboard built client-side** from accumulated TransferSettled events; CommunityUpdate syncs it.
- **IndexedStack** grows to 3 children — all screens stay alive; Community animation states preserved.

**How to apply:** Auth gate is in `MaterialApp.home`. Community tab is index 0. Notifiers: WalletStateNotifier (auth), CommunityStateNotifier (community), BESSStateNotifier (dashboard), GridTopologyNotifier (grid).
