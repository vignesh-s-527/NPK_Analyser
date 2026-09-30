import 'package:flutter/widgets.dart';
import '../models/domain.dart';

/// Person 2 supplies a BLE implementation and documented protocol adapter.
/// The farmer module intentionally does not make assumptions about packets.
abstract interface class NpkDeviceService {
  bool get isSimulator => false;
  Stream<List<DeviceInfo>> get discoveries;
  Stream<DeviceConnection> get connectionEvents;
  Stream<DeviceTestEvent> get testEvents;
  Future<void> startDiscovery();
  Future<void> stopDiscovery();
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> startTest();
}

class DeviceInfo {
  final String id, name;
  const DeviceInfo(this.id, this.name);
}

class DeviceConnection {
  final bool connected;
  final String? deviceId, error;
  final int? batteryPercent;
  const DeviceConnection(
      {required this.connected,
      this.deviceId,
      this.error,
      this.batteryPercent});
}

sealed class DeviceTestEvent {
  const DeviceTestEvent();
}

class TestStarted extends DeviceTestEvent {
  const TestStarted();
}

class TestSucceeded extends DeviceTestEvent {
  final NpkResult result;
  const TestSucceeded(this.result);
}

class TestFailed extends DeviceTestEvent {
  final String message, correctiveStep;
  const TestFailed(this.message, this.correctiveStep);
}

abstract interface class WeatherService {
  Future<WeatherSummary?> summary(double? lat, double? lon);
}

class WeatherSummary {
  final String description;
  final double? temperatureC;
  const WeatherSummary(this.description, this.temperatureC);
}

abstract interface class CropRecommendationService {
  Future<List<CropEstimate>> recommend(String language, NpkResult? soil);
}

/// Fertilizer advice is separate from crop-profit estimates. A safe response
/// may provide no application quantities when local calibration is missing.
abstract interface class FertilizerAdviceService {
  Future<FertilizerAdvice> recommend(NpkResult soil, {String? crop});
}

abstract interface class ReadingSubmissionService {
  Future<String> submitReading(NpkResult reading, {DateTime? measuredAt});
}

class FertilizerAdvice {
  final String? crop;
  final String status;
  final Map<String, double> nutrients;
  final List<String> additionalInformation, advice, sources;

  const FertilizerAdvice({
    required this.crop,
    required this.status,
    required this.nutrients,
    required this.additionalInformation,
    required this.advice,
    required this.sources,
  });
}

class CropEstimate {
  final String crop, currency, yieldUnit, priceUnit;
  final double? cost, yieldAmount, marketPrice, potentialProfit;
  const CropEstimate(this.crop,
      {this.cost,
      this.yieldAmount,
      this.marketPrice,
      this.potentialProfit,
      this.currency = '',
      this.yieldUnit = '',
      this.priceUnit = ''});
}

abstract interface class AiAssistantService {
  Stream<AssistantReply> ask(String question, String language);
  Future<void> contactExpert(String question);
}

class AssistantReply {
  final String text;
  final List<String> sources;
  final String answerType;
  final String providerStatus;
  final bool insufficientInformation;
  const AssistantReply(this.text,
      [this.sources = const [],
      this.answerType = 'general_information',
      this.providerStatus = 'unknown',
      this.insufficientInformation = false]);
}

abstract interface class FarmingCalendarService {
  Future<List<CalendarEvent>> events(int farmId);
  Future<int> saveTask(int farmId, CalendarEvent task);
  Future<void> setCompleted(int taskId, bool completed);
  Future<void> deleteTask(int taskId);
}

abstract interface class FarmingReminderService {
  Future<void> schedule(CalendarEvent event);
  Future<void> cancel(CalendarEvent event);
  Future<void> cancelNotification(int notificationId);
}

/// Optional implementations are injected at app startup by the integration module.
class FarmerServices {
  final NpkDeviceService? npkDevice;
  final FertilizerAdviceService? fertilizerAdvice;
  final ReadingSubmissionService? readingSubmission;
  final WeatherService? weather;
  final CropRecommendationService? cropRecommendations;
  final AiAssistantService? assistant;
  final FarmingCalendarService? calendar;
  final FarmingReminderService? reminders;
  final WidgetBuilder? expertDashboardBuilder;
  const FarmerServices(
      {this.npkDevice,
      this.fertilizerAdvice,
      this.readingSubmission,
      this.weather,
      this.cropRecommendations,
      this.assistant,
      this.calendar,
      this.reminders,
      this.expertDashboardBuilder});
}
