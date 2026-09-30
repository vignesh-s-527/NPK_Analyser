import 'package:flutter/material.dart';
import 'services/backend_services.dart';
import 'services/simulated_device_service.dart';
import 'services/contracts.dart';
import 'models/domain.dart';
import 'app/npk_app.dart';
import 'app/app_language.dart';
import 'data/local_store.dart';
import 'services/local_farming_services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStore.instance.initialize();
  await LocalFarmingReminderService.instance.initialize();
  final profile = await LocalStore.instance.profile();
  AppLanguage.select((profile?['language'] as String?) ?? 'en');
  const apiUrl = String.fromEnvironment('NPK_API_URL',
      defaultValue: 'http://10.0.2.2:8000');
  const simulatorEnabled =
      bool.fromEnvironment('NPK_SIMULATOR', defaultValue: true);
  final backend = NpkBackendClient(baseUrl: apiUrl);
  Future<NpkResult?> latestReading() async {
    final rows = await LocalStore.instance.latestTests(limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return NpkResult(
      (row['n'] as num).toDouble(),
      (row['p'] as num).toDouble(),
      (row['k'] as num).toDouble(),
      unit: row['unit'] as String,
      source: row['source'] as String? ?? 'manual',
    );
  }

  runApp(NpkApp(
      services: FarmerServices(
    npkDevice: simulatorEnabled ? SimulatedNpkDeviceService() : null,
    fertilizerAdvice: ApiFertilizerAdviceService(backend),
    readingSubmission: ApiReadingSubmissionService(backend),
    assistant: BackendAssistantService(backend, latestReading: latestReading),
    calendar: const LocalFarmingCalendarService(),
    reminders: LocalFarmingReminderService.instance,
  )));
}
