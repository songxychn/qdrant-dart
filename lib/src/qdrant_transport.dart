import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'qdrant_exception.dart';

/// Internal HTTP transport shared by the SDK's resource implementations.
///
/// This is not exported from `package:qdrant_dart/qdrant_dart.dart` and is not
/// a supported endpoint API.
final class QdrantTransport {
  /// Creates the internal transport for one Qdrant server.
  QdrantTransport({
    required this.baseUrl,
    required String? apiKey,
    required this.timeout,
  }) : _apiKey = apiKey;

  /// The configured Qdrant server URL.
  final Uri baseUrl;
  final String? _apiKey;

  /// The maximum duration for one HTTP request.
  final Duration timeout;
  final HttpClient _httpClient = HttpClient();

  /// Sends a JSON request to a relative Qdrant path.
  Future<QdrantResponse> send({
    required String method,
    required Uri path,
    Object? body,
  }) async {
    if (method.isEmpty) {
      throw ArgumentError.value(method, 'method', 'must not be empty.');
    }
    if (path.isAbsolute || path.path.startsWith('/')) {
      throw ArgumentError.value(path, 'path', 'must be a relative URI.');
    }

    final requestUri = _resolve(path);
    try {
      return await _send(
        method: method.toUpperCase(),
        uri: requestUri,
        body: body,
      ).timeout(timeout);
    } on QdrantException {
      rethrow;
    } on TimeoutException catch (error) {
      throw QdrantException(
        method: method.toUpperCase(),
        uri: requestUri,
        message: 'Request timed out after ${timeout.inMilliseconds} ms.',
        cause: error,
      );
    } on Object catch (error) {
      throw QdrantException(
        method: method.toUpperCase(),
        uri: requestUri,
        message: 'Could not contact Qdrant.',
        cause: error,
      );
    }
  }

  /// Releases HTTP resources held by this transport.
  void close({bool force = false}) => _httpClient.close(force: force);

  Uri _resolve(Uri path) {
    final basePath = baseUrl.path.isEmpty ? '/' : '${baseUrl.path}/';
    return baseUrl.replace(path: basePath).resolveUri(path);
  }

  Future<QdrantResponse> _send({
    required String method,
    required Uri uri,
    required Object? body,
  }) async {
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
    final apiKey = _apiKey;
    if (apiKey != null) {
      request.headers.set('api-key', apiKey);
    }
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }

    final response = await request.close();
    final responseBody = await utf8.decoder.bind(response).join();
    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      throw QdrantException(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
        message: _errorMessage(responseBody),
      );
    }
    return QdrantResponse(
      method: method,
      uri: uri,
      statusCode: response.statusCode,
      body: responseBody,
    );
  }

  String _errorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded case {'status': {'error': final String error}}) {
        return error;
      }
      if (decoded case {'message': final String message}) {
        return message;
      }
    } on FormatException {
      // Keep the server-provided body below when it is not JSON.
    }
    return responseBody.isEmpty
        ? 'Qdrant returned an empty error response.'
        : responseBody;
  }
}

/// An HTTP response returned by Qdrant's internal transport.
final class QdrantResponse {
  /// Creates an HTTP response returned by Qdrant.
  const QdrantResponse({
    required this.method,
    required this.uri,
    required this.statusCode,
    required this.body,
  });

  /// The request method used for this response.
  final String method;

  /// The request URI used for this response.
  final Uri uri;

  /// The HTTP status code returned by Qdrant.
  final int statusCode;

  /// The unparsed response body returned by Qdrant.
  final String body;

  /// Parses a successful response and preserves request context on failure.
  T parse<T>(T Function() parser) {
    try {
      return parser();
    } on FormatException catch (error) {
      throw QdrantException(
        method: method,
        uri: uri,
        statusCode: statusCode,
        message: 'Qdrant returned an incompatible successful response.',
        cause: error,
      );
    }
  }
}
