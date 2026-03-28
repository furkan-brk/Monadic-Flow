import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/bess_state.dart';
import 'core/models/community_state.dart';
import 'core/models/grid_state.dart';
import 'core/models/wallet_state.dart';
import 'core/notification_service.dart';
import 'core/websocket_service.dart';
import 'features/auth/wallet_connect_screen.dart';
import 'features/community/community_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/grid/grid_topology_screen.dart';
import 'features/map/singularity_map_screen.dart';

/// Module-level tab index notifier — shared between [AppShell] and
/// [NotificationService] so a notification tap can navigate to any tab
/// without needing a [BuildContext].
final tabIndexNotifier = ValueNotifier<int>(0);

/// Application entry point.
///
/// Boot order:
///   1. Restore any previously saved wallet session from SharedPreferences.
///   2. Create services and notifiers (outside widget tree for lifetime stability).
///   3. Hand off to [runApp] with the full provider tree.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Services ---
  final wsService = WebSocketService();

  // --- Auth ---
  final walletNotifier = WalletStateNotifier();
  // Restore persisted wallet address before the first frame is rendered so
  // the auth gate shows the correct screen without a visible flash.
  await walletNotifier.loadPersistedSession();

  // --- Notifications ---
  // Pass the module-level tabIndexNotifier so notification taps can switch
  // tabs without requiring a BuildContext.
  await NotificationService.instance.initialize(tabIndexNotifier);

  // --- Notifiers ---
  // BESSStateNotifier owns the WebSocket connection (calls ws.connect()).
  final bessNotifier = BESSStateNotifier(wsService);
  // GridTopologyNotifier + CommunityStateNotifier subscribe to the same
  // broadcast stream; neither calls connect() again.
  final gridNotifier = GridTopologyNotifier(wsService);
  final communityNotifier = CommunityStateNotifier(wsService);

  runApp(
    MultiProvider(
      providers: [
        // Raw WebSocket service — widgets can inspect the stream if needed.
        Provider<WebSocketService>.value(value: wsService),

        // Wallet auth — drives the auth gate.
        ChangeNotifierProvider<WalletStateNotifier>.value(
            value: walletNotifier),

        // BESS SOC / earnings / emergency mode — drives Dashboard screen.
        ChangeNotifierProvider<BESSStateNotifier>.value(value: bessNotifier),

        // IEEE 33-bus topology state — drives Grid screen.
        ChangeNotifierProvider<GridTopologyNotifier>.value(value: gridNotifier),

        // Community-level aggregations — drives Community screen.
        ChangeNotifierProvider<CommunityStateNotifier>.value(
            value: communityNotifier),
      ],
      child: const ParallelPulseApp(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Root widget
// ---------------------------------------------------------------------------

class ParallelPulseApp extends StatelessWidget {
  const ParallelPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParallelPulse',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
      ),
      // Auth gate: show WalletConnectScreen until wallet is connected.
      home: Consumer<WalletStateNotifier>(
        builder: (context, walletNotifier, _) {
          if (!walletNotifier.state.isConnected) {
            return const WalletConnectScreen();
          }
          return const AppShell();
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AppShell — bottom navigation between Community, Dashboard, and Grid
// ---------------------------------------------------------------------------

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Community tab (index 0) is the primary landing screen after login.
  int _selectedIndex = 0;

  /// [IndexedStack] keeps all screens alive so animation states and scroll
  /// positions are preserved when switching tabs.
  static const List<Widget> _screens = [
    CommunityScreen(),       // 0 — Main feature: Energy Community Hub
    DashboardScreen(),       // 1 — BESS SOC + earnings
    GridTopologyScreen(),    // 2 — IEEE 33-bus live topology
    SingularityMapScreen(),  // 3 — Interactive geo-map of IEEE 33-bus network
  ];

  @override
  void initState() {
    super.initState();
    // Listen for notification-driven tab changes from [NotificationService].
    tabIndexNotifier.addListener(_onTabIndexChanged);
  }

  @override
  void dispose() {
    tabIndexNotifier.removeListener(_onTabIndexChanged);
    super.dispose();
  }

  void _onTabIndexChanged() {
    final next = tabIndexNotifier.value;
    if (next != _selectedIndex && mounted) {
      setState(() => _selectedIndex = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          tabIndexNotifier.value = i;
        },
        backgroundColor: const Color(0xFF111122),
        indicatorColor: Colors.indigo.withAlpha(80),
        destinations: [
          // Community — main tab, shown first
          NavigationDestination(
            icon: _CommunityTabIcon(selected: false),
            selectedIcon: _CommunityTabIcon(selected: true),
            label: 'Topluluk',
          ),

          // Dashboard
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Panel',
          ),

          // Grid topology
          NavigationDestination(
            icon: _GridTabIcon(selected: false),
            selectedIcon: _GridTabIcon(selected: true),
            label: 'Şebeke',
          ),

          // Singularity Map
          NavigationDestination(
            icon: _MapTabIcon(selected: false),
            selectedIcon: _MapTabIcon(selected: true),
            label: 'Harita',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab icon helpers
// ---------------------------------------------------------------------------

/// Community tab icon — shows orange badge when grid is in emergency mode.
class _CommunityTabIcon extends StatelessWidget {
  const _CommunityTabIcon({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityStateNotifier>(
      builder: (_, notifier, __) {
        final isEmergency = notifier.snapshot.isEmergency;
        return Badge(
          isLabelVisible: isEmergency,
          backgroundColor: Colors.red,
          child: Icon(selected ? Icons.hub : Icons.hub_outlined),
        );
      },
    );
  }
}

/// Grid tab icon — shows orange badge when there is an active fault.
class _GridTabIcon extends StatelessWidget {
  const _GridTabIcon({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Consumer<GridTopologyNotifier>(
      builder: (_, notifier, __) {
        final hasFault = notifier.failedLineKeys.isNotEmpty;
        return Badge(
          isLabelVisible: hasFault,
          backgroundColor: Colors.orange,
          child: Icon(
            selected ? Icons.electrical_services : Icons.electrical_services_outlined,
          ),
        );
      },
    );
  }
}

/// Map tab icon — shows a red badge when the grid has an active emergency.
class _MapTabIcon extends StatelessWidget {
  const _MapTabIcon({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Consumer<GridTopologyNotifier>(
      builder: (_, notifier, __) {
        final hasEmergency = notifier.failedLineKeys.isNotEmpty;
        return Badge(
          isLabelVisible: hasEmergency,
          backgroundColor: Colors.red,
          child: Icon(selected ? Icons.map : Icons.map_outlined),
        );
      },
    );
  }
}
