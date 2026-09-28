import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:npk_farmer/models/domain.dart';
import 'package:npk_farmer/services/backend_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('client sends reading provenance and maps safe advice and AI status',
      () async {
    final requests = <String, Map<String, dynamic>>{};
    final fakeClient = _FakeHttpClient((uri, body) {
      requests[uri.path] = body;
      return switch (uri.path) {
        '/v1/readings' => {'reading_id': 'remote-123'},
        '/v1/recommendations' => {
            'crop': body['crop'],
            'recommendation_status': 'insufficient_local_calibration',
            'nutrient_status': {
              'nitrogen': {'value': 32.0},
            },
            'additional_information_required': ['local test method'],
            'advice': ['Do not use a rate from this reading alone.'],
            'sources': ['https://example.test/source'],
          },
        '/v1/assistant' => {
            'answer': 'Please use locally calibrated soil guidance.',
            'sources': ['https://example.test/source'],
            'answer_type': 'contextual',
            'provider_status': 'ollama_generated',
            'insufficient_information': false,
          },
        _ => <String, Object?>{'detail': 'not found'},
      };
    });

    final client = NpkBackendClient(
        baseUrl: 'http://test.invalid',
        client: fakeClient,
        timeout: const Duration(seconds: 3));
    addTearDown(client.close);
    const reading = NpkResult(32, 18, 47, source: 'simulated', unit: 'mg/kg');

    final measuredAt = DateTime.parse('2026-09-27T10:00:00Z');
    expect(await client.createReading(reading, measuredAt: measuredAt),
        'remote-123');
    expect(requests['/v1/readings']?['source'], 'simulated');
    expect(
        requests['/v1/readings']?['measured_at'], measuredAt.toIso8601String());

    final advice = await client.recommend(reading, crop: 'Rice');
    expect(advice.status, 'insufficient_local_calibration');
    expect(advice.nutrients['nitrogen'], 32.0);
    expect(
        advice.advice, contains('Do not use a rate from this reading alone.'));

    final reply = await client.ask('What does this soil test mean?', 'en',
        reading: reading);
    expect(requests['/v1/assistant']?['reading']['unit'], 'mg/kg');
    expect(reply.providerStatus, 'ollama_generated');
    expect(reply.sources, isNotEmpty);
  });

  test('client rejects invalid readings before sending them', () async {
    final client = NpkBackendClient(
        baseUrl: 'http://test.invalid',
        client: _FakeHttpClient((uri, body) => <String, Object?>{}));
    addTearDown(client.close);
    await expectLater(
      client.createReading(const NpkResult(-1, 2, 3)),
      throwsA(isA<BackendServiceException>()),
    );
  });
}

typedef _ResponseFactory = Map<String, Object?> Function(
    Uri uri, Map<String, dynamic> requestBody);

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(this._createResponse);

  final _ResponseFactory _createResponse;

  @override
  Future<HttpClientRequest> postUrl(Uri url) async =>
      _FakeRequest(url, _createResponse);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRequest implements HttpClientRequest {
  _FakeRequest(this.uri, this._createResponse);

  @override
  final Uri uri;
  final _ResponseFactory _createResponse;
  final _FakeHeaders _headers = _FakeHeaders();
  final StringBuffer _body = StringBuffer();

  @override
  HttpHeaders get headers => _headers;

  @override
  void write(Object? object, [Encoding? encoding]) => _body.write(object);

  @override
  Future<HttpClientResponse> close() async {
    final requestBody = jsonDecode(_body.toString()) as Map<String, dynamic>;
    return _FakeResponse(jsonEncode(_createResponse(uri, requestBody)));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHeaders implements HttpHeaders {
  @override
  ContentType? contentType;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeResponse(String body) : _bytes = utf8.encode(body);

  final List<int> _bytes;

  @override
  int get statusCode => HttpStatus.ok;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      Stream<List<int>>.value(_bytes).listen(onData,
          onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
