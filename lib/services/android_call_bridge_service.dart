import 'dart:io';

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
    final token = prefs.getString(_tokenKey) ?? '';
    return _invokeNative(
      'startNativeBridge',
      <String, dynamic>{'port': port, 'token': token},
    );
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
