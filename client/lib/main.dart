import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/models/bess_state.dart';
import 'core/websocket_service.dart';
import 'features/dashboard/dashboard_screen.dart';

/// Application entry point.
///
/// [WebSocketService] and [BESSStateNotifier] are created once here, outside
/// the widget tree, so they survive widget rebuilds and are accessible to any
/// descendant via [Provider] / [Consumer].
void main() {
  // Create the service and notifier eagerly so the WebSocket connection is
  // established before the first frame is drawn.
  final wsService = WebSocketService();
  final bessNotifier = BESSStateNotifier(wsService);

  runApp(
    MultiProvider(
      providers: [
        // Expose the raw service in case widgets need to call connect() or
        // inspect the stream directly.
        Provider<WebSocketService>.value(value: wsService),

        // Main state notifier — drives all UI rebuilds.
        ChangeNotifierProvider<BESSStateNotifier>.value(value: bessNotifier),
      ],
      child: const ParallelPulseApp(),
    ),
  );
}

/// Root widget of the ParallelPulse application.
class ParallelPulseApp extends StatelessWidget {
  const ParallelPulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ParallelPulse BESS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}
