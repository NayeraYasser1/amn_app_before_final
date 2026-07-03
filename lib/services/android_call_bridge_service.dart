import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AndroidCallBridgeService {
  AndroidCallBridgeService._();

  static final AndroidCallBridgeService instance = AndroidCallBridgeService._();
  static const MethodChannel _channel = MethodChannel('amn_app/android_calls');
  static const String _portKey = 'android_call_bridge_port';
  static const String _tokenKey = 'android_call_bridge_token';

  bool _started = false;

  Future<void> start() async {
    if (_started || kIsWeb || !Platform.isAndroid) {
      return;
    }

    await _channel.invokeMethod('initializeBridge');
    await restartBridge();
    _started = true;
  }

  Future<Map<String, dynamic>> restartBridge() async {
    final prefs = await SharedPreferences.getInstance();
    final port = prefs.getInt(_portKey) ?? 8765;
    final token = await _ensureToken(prefs);
    return _invokeNative(
      'startNativeBridge',
      <String, dynamic>{'port': port, 'token': token},
    );
  }

  /// Returns the bridge auth token, generating and persisting a strong random
  /// one on first run. Without a non-blank token the native server treats every
  /// request as authorized, so any co-resident app could POST /answer, /end etc.
  /// to the loopback port and control the user's calls. Requiring a token that
  /// never leaves the device closes that hole.
  Future<String> _ensureToken(SharedPreferences prefs) async {
    final existing = prefs.getString(_tokenKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final token = List<String>.generate(
      32,
      (_) => rng.nextInt(16).toRadixString(16),
    ).join();
    await prefs.setString(_tokenKey, token);
    return token;
  }

  Future<Map<String, dynamic>> stopBridge() async {
    return _invokeNative('stopNativeBridge');
  }

  Future<Map<String, dynamic>> getBridgeStatus() async {
    return _invokeNative('getBridgeRuntimeStatus');
  }

  Future<Map<String, dynamic>> getCallStatus() async {
    return _invokeNative('getCallStatus');
  }

  Future<void> requestBatteryOptimizationExemption() async {
    await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
  }

  Future<Map<String, dynamic>> _invokeNative(
    String method, [
    Map<String, dynamic>? arguments,
  ]) async {
    try {
      final raw = await _channel.invokeMethod(
        method,
        arguments ?? <String, dynamic>{},
      );
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return <String, dynamic>{
        'ok': false,
        'error': 'Native bridge returned an invalid payload.',
      };
    } on PlatformException catch (exc) {
      return <String, dynamic>{
        'ok': false,
        'error': exc.message ?? exc.code,
      };
    } catch (exc) {
      return <String, dynamic>{'ok': false, 'error': exc.toString()};
    }
  }
}
