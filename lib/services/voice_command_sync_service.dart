import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VoiceCommandSyncService {
  VoiceCommandSyncService._();

  static final VoiceCommandSyncService instance = VoiceCommandSyncService._();
  static const _baseUrlKey = 'pi_voice_bridge_base_url';
  static const _defaultBaseUrl = 'http://192.168.1.8:8876';

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_baseUrlKey) ?? _defaultBaseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, value.trim());
  }

  Future<List<Map<String, dynamic>>> loadCatalog() async {
    final raw = await rootBundle.loadString('assets/voice/voice_command_catalog.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final commands = (data['commands'] as List?) ?? const [];
    return commands.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> getBridgeStatus() async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/voice/status')).timeout(
        const Duration(seconds: 3),
      );
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      payload['http_status'] = response.statusCode;
      payload['bridge_connected'] = response.statusCode == 200;
      return payload;
    } catch (exc) {
      return <String, dynamic>{
        'ok': false,
        'bridge_connected': false,
        'error': exc.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> sendCommand(
    String text, {
    String source = 'app',
    String driverId = '',
  }) async {
    final baseUrl = await getBaseUrl();
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/voice/command'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'text': text,
              'source': source,
              'driver_id': driverId,
            }),
          )
          .timeout(const Duration(seconds: 4));
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      payload['http_status'] = response.statusCode;
      return payload;
    } catch (exc) {
      return <String, dynamic>{
        'ok': false,
        'reply': 'I could not reach the car software right now.',
        'error': exc.toString(),
      };
    }
  }
}
