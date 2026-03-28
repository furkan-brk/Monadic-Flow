import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kWalletAddressKey = 'pp_wallet_address';
const _kWalletDemoKey = 'pp_wallet_is_demo';

// ---------------------------------------------------------------------------
// Immutable state
// ---------------------------------------------------------------------------

/// Immutable snapshot of the connected wallet.
class WalletState {
  const WalletState({
    this.address,
    this.isDemo = false,
  });

  /// EVM wallet address (0x…). Null means not connected.
  final String? address;

  /// True when the address was auto-generated for demo / testing purposes.
  final bool isDemo;

  bool get isConnected => address != null;

  /// Returns the address shortened for display: "0x1234…abcd".
  String get shortAddress {
    if (address == null) return '';
    return '${address!.substring(0, 6)}…${address!.substring(address!.length - 4)}';
  }

  WalletState copyWith({String? address, bool? isDemo}) {
    return WalletState(
      address: address ?? this.address,
      isDemo: isDemo ?? this.isDemo,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages wallet connection state and persists it across app restarts using
/// [SharedPreferences].
///
/// Auth pattern:
///   - [connect] — validates and stores a user-supplied address.
///   - [connectDemo] — generates a deterministic demo address, no real keys.
///   - [disconnect] — clears persisted session and resets state.
class WalletStateNotifier extends ChangeNotifier {
  WalletStateNotifier();

  WalletState _state = const WalletState();

  WalletState get state => _state;

  /// Load persisted wallet from [SharedPreferences] on app startup.
  /// Call this once from `main()` before [runApp].
  Future<void> loadPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kWalletAddressKey);
    final isDemo = prefs.getBool(_kWalletDemoKey) ?? false;
    if (saved != null && _isValidAddress(saved)) {
      _state = WalletState(address: saved, isDemo: isDemo);
      notifyListeners();
    }
  }

  /// Connect with a user-supplied 0x address string.
  ///
  /// Returns an error message on invalid input, or null on success.
  Future<String?> connect(String raw) async {
    final trimmed = raw.trim();
    if (!_isValidAddress(trimmed)) {
      return 'Geçerli bir Ethereum adresi girin (0x ile başlayan 42 karakter)';
    }
    await _persist(trimmed, isDemo: false);
    _state = WalletState(address: trimmed, isDemo: false);
    notifyListeners();
    return null;
  }

  /// Generate a random pseudo-address for demo / presentation purposes.
  Future<void> connectDemo() async {
    final addr = _generateDemoAddress();
    await _persist(addr, isDemo: true);
    _state = WalletState(address: addr, isDemo: true);
    notifyListeners();
  }

  /// Disconnect: clear persisted session and reset state.
  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kWalletAddressKey);
    await prefs.remove(_kWalletDemoKey);
    _state = const WalletState();
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  /// Basic EVM address format check: 0x followed by exactly 40 hex chars.
  static bool _isValidAddress(String addr) {
    return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(addr);
  }

  /// Generates a 40-hex-char random address (no real private key backing).
  static String _generateDemoAddress() {
    final rng = Random.secure();
    final bytes = List<int>.generate(20, (_) => rng.nextInt(256));
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hex';
  }

  Future<void> _persist(String address, {required bool isDemo}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kWalletAddressKey, address);
    await prefs.setBool(_kWalletDemoKey, isDemo);
  }
}
