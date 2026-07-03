import 'dart:async';

import 'package:flutter/material.dart';

import '../services/android_call_bridge_service.dart';

class AndroidCallBridgeStatusScreen extends StatefulWidget {
  const AndroidCallBridgeStatusScreen({super.key});

  @override
  State<AndroidCallBridgeStatusScreen> createState() =>
      _AndroidCallBridgeStatusScreenState();
}

class _AndroidCallBridgeStatusScreenState
    extends State<AndroidCallBridgeStatusScreen> {
  final _bridge = AndroidCallBridgeService.instance;

  Timer? _pollTimer;
  Map<String, dynamic> _bridgeStatus = const <String, dynamic>{};
  Map<String, dynamic> _callStatus = const <String, dynamic>{};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshStatus(showLoader: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus({bool showLoader = true}) async {
    if (showLoader && mounted) {
      setState(() => _loading = true);
    }

    final results = await Future.wait<dynamic>([
      _bridge.getBridgeStatus(),
      _bridge.getCallStatus(),
    ]);

    if (!mounted) {
      return;
    }

    setState(() {
      _bridgeStatus = Map<String, dynamic>.from(results[0] as Map);
      _callStatus = Map<String, dynamic>.from(results[1] as Map);
      _loading = false;
    });
  }

  Future<void> _runAction(
    Future<Map<String, dynamic>> Function() action,
    String successMessage,
  ) async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    await _refreshStatus(showLoader: false);
    if (!mounted) return;
    final ok = result['ok'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? successMessage : '${result['error'] ?? 'Action failed.'}'),
        backgroundColor: ok ? Colors.green[700] : Colors.red[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final running = _bridgeStatus['running'] == true;
    final defaultDialer = _bridgeStatus['default_dialer'] == true;
    final permissionsGranted = _bridgeStatus['permissions_granted'] == true;
    final batteryIgnored =
        _bridgeStatus['battery_optimization_ignored'] == true;
    final port = _bridgeStatus['port'] ?? 8765;
    final callState = (_callStatus['state'] ?? 'idle').toString();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Android Call Bridge',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refreshStatus,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildStatusCard(
                      title: 'Bridge Runtime',
                      children: [
                        _buildRow('Running', running ? 'Yes' : 'No'),
                        _buildRow('Port', '$port'),
                        _buildRow('Default dialer', defaultDialer ? 'Yes' : 'No'),
                        _buildRow(
                          'Permissions',
                          permissionsGranted ? 'Granted' : 'Missing',
                        ),
                        _buildRow(
                          'Battery optimization',
                          batteryIgnored ? 'Ignored' : 'Still optimized',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(
                      title: 'Live Call State',
                      children: [
                        _buildRow('State', callState),
                        _buildRow(
                          'Caller',
                          (_callStatus['caller_name'] ?? '').toString().isEmpty
                              ? 'No caller'
                              : (_callStatus['caller_name'] ?? '').toString(),
                        ),
                        _buildRow(
                          'Number',
                          (_callStatus['caller_number'] ?? '').toString().isEmpty
                              ? '--'
                              : (_callStatus['caller_number'] ?? '').toString(),
                        ),
                        _buildRow(
                          'Bluetooth audio',
                          _callStatus['bluetooth_audio'] == true ? 'On' : 'Off',
                        ),
                        _buildRow(
                          'Speaker',
                          _callStatus['speaker_on'] == true ? 'On' : 'Off',
                        ),
                        _buildRow(
                          'Muted',
                          _callStatus['muted'] == true ? 'Yes' : 'No',
                        ),
                        const SizedBox(height: 10),
                        Text(
                          (_callStatus['message'] ?? '').toString(),
                          style: TextStyle(color: Colors.grey[300], fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStatusCard(
                      title: 'Bridge Controls',
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _actionButton(
                              label: 'Restart Bridge',
                              onTap: () => _runAction(
                                _bridge.restartBridge,
                                'Bridge restarted.',
                              ),
                            ),
                            _actionButton(
                              label: 'Stop Bridge',
                              onTap: () => _runAction(
                                _bridge.stopBridge,
                                'Bridge stopped.',
                              ),
                            ),
                            _actionButton(
                              label: 'Ignore Battery Optimization',
                              onTap: () async {
                                await _bridge.requestBatteryOptimizationExemption();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Approve the Android battery optimization prompt if it appears.',
                                    ),
                                  ),
                                );
                                await Future.delayed(const Duration(seconds: 1));
                                await _refreshStatus(showLoader: false);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Keep this screen available while validating calls. The Raspberry Pi should point to this phone on port 8765.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 220,
      child: ElevatedButton(
        onPressed: _busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
