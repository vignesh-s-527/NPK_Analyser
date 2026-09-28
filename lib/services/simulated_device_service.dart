import 'dart:async';

import '../models/domain.dart';
import 'contracts.dart';

/// Development-only device simulator. Its fixed demonstration values are
/// labelled as simulated and must never be presented as analyzer measurements.
class SimulatedNpkDeviceService implements NpkDeviceService {
  static const _demoDevice = DeviceInfo('demo://npk-analyzer', 'Demo analyzer');

  final _discoveries = StreamController<List<DeviceInfo>>.broadcast();
  final _connections = StreamController<DeviceConnection>.broadcast();
  final _tests = StreamController<DeviceTestEvent>.broadcast();
  bool _connected = false;
  bool _closed = false;

  @override
  bool get isSimulator => true;

  @override
  Stream<List<DeviceInfo>> get discoveries => _discoveries.stream;

  @override
  Stream<DeviceConnection> get connectionEvents => _connections.stream;

  @override
  Stream<DeviceTestEvent> get testEvents => _tests.stream;

  @override
  Future<void> startDiscovery() async {
    _ensureOpen();
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!_closed) _discoveries.add(const [_demoDevice]);
  }

  @override
  Future<void> stopDiscovery() async {
    _ensureOpen();
    _discoveries.add(const []);
  }

  @override
  Future<void> connect(String deviceId) async {
    _ensureOpen();
    if (deviceId != _demoDevice.id) {
      throw ArgumentError.value(deviceId, 'deviceId', 'Unknown demo device');
    }
    _connected = true;
    _connections.add(const DeviceConnection(
        connected: true, deviceId: 'demo://npk-analyzer'));
  }

  @override
  Future<void> disconnect() async {
    _ensureOpen();
    _connected = false;
    _connections.add(const DeviceConnection(connected: false));
  }

  @override
  Future<void> startTest() async {
    _ensureOpen();
    if (!_connected) throw StateError('Connect to the demo analyzer first.');
    _tests.add(const TestStarted());
    await Future<void>.delayed(const Duration(seconds: 2));
    if (_closed || !_connected) return;
    _tests.add(const TestSucceeded(NpkResult(
      32,
      18,
      47,
      unit: 'mg/kg',
      source: 'simulated',
    )));
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await Future.wait([
      _discoveries.close(),
      _connections.close(),
      _tests.close(),
    ]);
  }

  void _ensureOpen() {
    if (_closed) throw StateError('The demo analyzer has been disposed.');
  }
}
