import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Push-to-Earn notification service.
///
/// Only active on Android and iOS; on desktop (Windows) it is a no-op so
/// the app can still run and compile without platform-specific native code.
///
/// Usage:
/// ```dart
/// await NotificationService.instance.initialize(tabIndexNotifier);
/// NotificationService.instance.showEmergencyAlert(busId: 7);
/// NotificationService.instance.showEarningsAlert(amountWh: 50000, earningsWei: 250000);
/// ```
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  ValueNotifier<int>? _tabNotifier;

  bool get _isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialise the plugin and store [tabNotifier] so notification taps can
  /// navigate the user to the Community tab (index 0).
  Future<void> initialize(ValueNotifier<int> tabNotifier) async {
    _tabNotifier = tabNotifier;

    if (!_isMobile) {
      debugPrint('[NotificationService] Desktop platform — notifications disabled.');
      return;
    }

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }

    debugPrint('[NotificationService] Initialised.');
  }

  // ---------------------------------------------------------------------------
  // Notification triggers
  // ---------------------------------------------------------------------------

  /// Show a high-priority emergency alert when [EmergencyActivated] arrives.
  ///
  /// Tapping the notification navigates to the Community tab (index 0) where
  /// the "Teklif Ver" FAB is visible.
  Future<void> showEmergencyAlert({int busId = 0}) async {
    if (!_isMobile) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'emergency_channel',
        'Acil Durum',
        channelDescription: 'Şebeke arızası bildirimleri',
        importance: Importance.max,
        priority: Priority.high,
        enableVibration: true,
        playSound: true,
        styleInformation: BigTextStyleInformation(
          'Hastane ve okullara enerji sağlamak için BESS\'inizi devreye alın.',
        ),
        color: _kRedArgb,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _plugin.show(
      _kEmergencyNotificationId,
      '⚡ ACİL MOD — 5× Fiyat Aktif',
      busId > 0
          ? 'Bus $busId hattında arıza tespit edildi. Teklif vermek için dokun.'
          : 'Şebeke arızası tespit edildi. Teklif vermek için dokun.',
      details,
      payload: 'community',
    );
  }

  /// Show an earnings notification when a [TransferSettled] event arrives.
  Future<void> showEarningsAlert({
    required int amountWh,
    required int earningsWei,
  }) async {
    if (!_isMobile) return;

    final amountKwh = (amountWh / 1000).toStringAsFixed(1);
    final earningsGwei = (earningsWei / 1e9).toStringAsFixed(2);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'earnings_channel',
        'Kazanç',
        channelDescription: 'BESS enerji transferi kazanç bildirimleri',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        enableVibration: false,
        color: _kGreenArgb,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: true,
        presentSound: false,
      ),
    );

    await _plugin.show(
      _kEarningsNotificationId,
      '💰 Enerji Transferi Tamamlandı',
      '$amountKwh kWh sağlandı — $earningsGwei Gwei kazanıldı.',
      details,
      payload: 'community',
    );
  }

  // ---------------------------------------------------------------------------
  // Tap handler
  // ---------------------------------------------------------------------------

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload == 'community') {
      // Navigate to the Community tab.
      _tabNotifier?.value = 0;
    }
  }

  // ---------------------------------------------------------------------------
  // Constants
  // ---------------------------------------------------------------------------

  static const int _kEmergencyNotificationId = 1001;
  static const int _kEarningsNotificationId = 1002;

  // Android notification accent colours (ARGB int).
  static const Color _kRedArgb = Color(0xFFD32F2F);
  static const Color _kGreenArgb = Color(0xFF388E3C);
}
