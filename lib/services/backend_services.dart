import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/domain.dart';
import 'contracts.dart';

class BackendServiceException implements Exception {
  final int? statusCode;
  final String message;

  const BackendServiceException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// Small JSON client for the FastAPI backend. It uses dart:io so it adds no
/// third-party networking dependency to the Android application.
class NpkBackendClient {
  NpkBackendClient({
    required String baseUrl,
    HttpClient? client,
    this.timeout = const Duration(seconds: 12),
  })  : _baseUri = Uri.parse(baseUrl),
        _client = client ?? HttpClient() {
    if (!_baseUri.hasScheme || !_baseUri.hasAuthority) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Must be an absolute URL');
    }
  }

  final Uri _baseUri;
  final HttpClient _client;
  final Duration timeout;

  Future<Map<String, dynamic>> _post(
      String path, Map<String, Object?> payload) async {
    try {
      final request =
          await _client.postUrl(_baseUri.resolve(path)).timeout(timeout);
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(payload));
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join().timeout(timeout);
      final body = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      if (body is! Map<String, dynamic>) {
        throw const BackendServiceException(
            'The backend returned an invalid response.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = body['detail'];
        throw BackendServiceException(
          detail is String ? detail : 'The backend request failed.',
          statusCode: response.statusCode,
        );
      }
      return body;
    } on BackendServiceException {
      rethrow;
    } on TimeoutException {
      throw const BackendServiceException('The backend request timed out.');
    } on SocketException {
      throw const BackendServiceException('The backend could not be reached.');
    } on FormatException {
      throw const BackendServiceException('The backend returned invalid JSON.');
    } on HttpException {
      throw const BackendServiceException('The backend connection failed.');
    } on IOException {
      throw const BackendServiceException('The backend connection failed.');
    }
  }

  Future<Map<String, dynamic>> listReadings(
      {int limit = 50, int offset = 0}) async {
    if (limit < 1 || limit > 200 || offset < 0) {
      throw ArgumentError('limit must be 1-200 and offset cannot be negative');
    }
    try {
      final uri = _baseUri.resolve('/v1/readings').replace(queryParameters: {
        'limit': '$limit',
        'offset': '$offset',
      });
      final request = await _client.getUrl(uri).timeout(timeout);
      final response = await request.close().timeout(timeout);
      final text = await utf8.decoder.bind(response).join().timeout(timeout);
      final body = jsonDecode(text);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw BackendServiceException('The backend request failed.',
            statusCode: response.statusCode);
      }
      if (body is! Map<String, dynamic>) {
        throw const BackendServiceException(
            'The backend returned invalid JSON.');
      }
      return body;
    } on TimeoutException {
      throw const BackendServiceException('The backend request timed out.');
    } on SocketException {
      throw const BackendServiceException('The backend could not be reached.');
    } on FormatException {
      throw const BackendServiceException('The backend returned invalid JSON.');
    } on HttpException {
      throw const BackendServiceException('The backend connection failed.');
    } on IOException {
      throw const BackendServiceException('The backend connection failed.');
    }
  }

  Future<String> createReading(NpkResult reading,
      {DateTime? measuredAt}) async {
    _validate(reading);
    final response = await _post('/v1/readings', {
      'nitrogen': reading.nitrogen,
      'phosphorus': reading.phosphorus,
      'potassium': reading.potassium,
      'unit': reading.unit,
      'source': _source(reading.source),
      if (measuredAt != null)
        'measured_at': measuredAt.toUtc().toIso8601String(),
    });
    final id = response['reading_id'];
    if (id is! String || id.isEmpty) {
      throw const BackendServiceException(
          'The backend response has no reading ID.');
    }
    return id;
  }

  Future<FertilizerAdvice> recommend(NpkResult reading, {String? crop}) async {
    _validate(reading);
    final response = await _post('/v1/recommendations', {
      'nitrogen': reading.nitrogen,
      'phosphorus': reading.phosphorus,
      'potassium': reading.potassium,
      'unit': reading.unit,
      if (crop != null && crop.trim().isNotEmpty) 'crop': crop.trim(),
    });
    final statuses = response['nutrient_status'];
    final nutrients = <String, double>{};
    if (statuses is Map<String, dynamic>) {
      for (final name in const ['nitrogen', 'phosphorus', 'potassium']) {
        final item = statuses[name];
        if (item is Map<String, dynamic> && item['value'] is num) {
          nutrients[name] = (item['value'] as num).toDouble();
        }
      }
    }
    return FertilizerAdvice(
      crop: response['crop'] as String?,
      status: response['recommendation_status'] as String? ?? 'unavailable',
      nutrients: nutrients,
      additionalInformation:
          _strings(response['additional_information_required']),
      advice: _strings(response['advice']),
      sources: _strings(response['sources']),
    );
  }

  Future<AssistantReply> ask(String question, String language,
      {NpkResult? reading, String? crop}) async {
    final response = await _post('/v1/assistant', {
      'question': question,
      'language': language == 'ta' ? 'ta' : 'en',
      if (reading != null)
        'reading': {
          'nitrogen': reading.nitrogen,
          'phosphorus': reading.phosphorus,
          'potassium': reading.potassium,
          'unit': reading.unit,
        },
      if (crop != null && crop.trim().isNotEmpty) 'crop': crop.trim(),
    });
    final answer = response['answer'];
    if (answer is! String || answer.isEmpty) {
      throw const BackendServiceException(
          'The assistant returned an empty answer.');
    }
    return AssistantReply(
      answer,
      _strings(response['sources']),
      response['answer_type'] as String? ?? 'general_information',
      response['provider_status'] as String? ?? 'unknown',
      response['insufficient_information'] as bool? ?? false,
    );
  }

  Future<void> close() async => _client.close(force: true);

  static List<String> _strings(Object? value) => value is List
      ? value.whereType<String>().toList(growable: false)
      : const [];

  static String _source(String value) =>
      const {'device', 'simulated', 'manual'}.contains(value)
          ? value
          : 'manual';

  static void _validate(NpkResult reading) {
    if (!reading.isValid) {
      throw const BackendServiceException(
          'The reading must contain finite, non-negative NPK values in mg/kg.');
    }
  }
}

class BackendAssistantService implements AiAssistantService {
  BackendAssistantService(this.client, {this.latestReading});

  final NpkBackendClient client;
  final Future<NpkResult?> Function()? latestReading;

  @override
  Stream<AssistantReply> ask(String question, String language) async* {
    final reading = await latestReading?.call();
    yield await client.ask(question, language, reading: reading);
  }

  @override
  Future<void> contactExpert(String question) async {
    throw UnsupportedError('Expert messaging is not configured.');
  }
}

class ApiFertilizerAdviceService implements FertilizerAdviceService {
  const ApiFertilizerAdviceService(this.client);

  final NpkBackendClient client;

  @override
  Future<FertilizerAdvice> recommend(NpkResult soil, {String? crop}) =>
      client.recommend(soil, crop: crop);
}

class ApiReadingSubmissionService implements ReadingSubmissionService {
  const ApiReadingSubmissionService(this.client);

  final NpkBackendClient client;

  @override
  Future<String> submitReading(NpkResult reading, {DateTime? measuredAt}) =>
      client.createReading(reading, measuredAt: measuredAt);
}
