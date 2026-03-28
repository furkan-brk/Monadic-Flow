import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/bess_state.dart';
import 'core/models/grid_state.dart';
import 'core/websocket_service.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/grid/grid_topology_screen.dart';

/// Application entry point.
///
/// Services and notifiers are created once here, outside the widget tree, so
/// they survive widget rebuilds and are accessible to any descendant via
/// [Provider] / [Consumer].
void main() {
  // --- Services ---
  final wsService = WebSocketService();

  // --- Notifiers ---
  // BESSStateNotifier owns the WebSocket connection (calls ws.connect()).
  final bessNotifier = BESSStateNotifier(wsService);
  // GridTopologyNotifier subscribes to the same broadcast stream; it does NOT
  // call connect() again.
  final gridNotifier = GridTopologyNotifier(wsService);

  runApp(
    MultiProvider(
      providers: [
        // Expose the raw service so widgets can inspect the stream if needed.
        Provider<WebSocketService>.value(value: wsService),

        // BESS SOC / earnings / emergency mode — drives Dashboard screen.
        ChangeNotifierProvider<BESSStateNotifier>.value(value: bessNotifier),

        // IEEE 33-bus topology state — drives Grid screen.
        ChangeNotifierProvider<GridTopologyNotifier>.value(value: gridNotifier),
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
      title: 'ParallelPulse BESS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const AppShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// AppShell — bottom navigation between Dashboard and Grid View
// ---------------------------------------------------------------------------

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  /// Screens are in an [IndexedStack] so both stay alive and their scroll
  /// positions / animation states are preserved when switching tabs.
  static const List<Widget> _screens = [
    DashboardScreen(),
    GridTopologyScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        backgroundColor: Colors.grey.shade900,
        indicatorColor: Colors.indigo.withAlpha(80),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: _GridTabIcon(selected: false),
            selectedIcon: _GridTabIcon(selected: true),
            label: 'Grid',
          ),
        ],
      ),
    );
  }
}

/// Grid tab icon — shows an orange badge when there is an active fault.
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
          child: Icon(selected ? Icons.hub : Icons.hub_outlined),
        );
      },
    );
  }
}
