import 'package:flutter_test/flutter_test.dart';
import 'package:npk_farmer/services/contracts.dart';
import 'package:npk_farmer/services/simulated_device_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('simulator emits a labelled demo reading after connection', () async {
    final service = SimulatedNpkDeviceService();
    addTearDown(service.dispose);
    expect(service.isSimulator, isTrue);

    final discoveries = service.discoveries.first;
    await service.startDiscovery();
    final devices = await discoveries;
    expect(devices, hasLength(1));
    expect(devices.single.id, startsWith('demo://'));

    final connection = service.connectionEvents.first;
    await service.connect(devices.single.id);
    expect((await connection).connected, isTrue);

    final events = service.testEvents.take(2).toList();
    await service.startTest();
    final result = await events;
    expect(result.first, isA<TestStarted>());
    expect(result.last, isA<TestSucceeded>());
    expect((result.last as TestSucceeded).result.source, 'simulated');
  });
}
