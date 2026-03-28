import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/bess_state.dart';
import 'widgets/earnings_card.dart';
import 'widgets/emergency_banner.dart';
import 'widgets/event_log_list.dart';
import 'widgets/soc_gauge.dart';

/// Primary screen of the ParallelPulse BESS dashboard.
///
/// Rebuilds via [Consumer]<[BESSStateNotifier]> whenever new WebSocket events
/// arrive. The layout stacks:
///
///   1. [EmergencyBanner] — only visible in emergency mode.
///   2. [SOCGauge] — circular charge level indicator.
///   3. [EarningsCard] — cumulative on-chain earnings.
///   4. [EventLogList] — last received event type and timestamp.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ParallelPulse \u26a1'),
        centerTitle: false,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Consumer<BESSStateNotifier>(
        builder: (context, notifier, _) {
          final state = notifier.state;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Emergency banner is only shown when relevant.
                if (state.emergencyMode) const EmergencyBanner(),

                const SizedBox(height: 32),

                // SOC gauge — centred horizontally.
                Center(
                  child: SOCGauge(soc: state.socPercent),
                ),

                const SizedBox(height: 24),

                EarningsCard(earningsWei: state.earningsWei),

                EventLogList(
                  lastEventType: state.lastEventType,
                  lastTimestampMs: state.lastTimestampMs,
                ),

                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
