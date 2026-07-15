import 'qdrant_transport.dart';

/// Configures a connection to a Qdrant server.
///
/// [baseUrl] must use HTTP or HTTPS. Supply [apiKey] only from a trusted
/// server-side environment; it is never exposed by this API or included in
/// errors.
final class QdrantClient {
  /// Creates a client that will connect to [baseUrl].
  QdrantClient({
    required Uri baseUrl,
    String? apiKey,
    Duration timeout = defaultRequestTimeout,
  })  : baseUrl = _validateBaseUrl(baseUrl),
        timeout = _validateTimeout(timeout) {
    _transport = QdrantTransport(
      baseUrl: this.baseUrl,
      apiKey: _validateApiKey(apiKey),
      timeout: this.timeout,
    );
  }

  /// The default maximum duration for one HTTP request.
  static const defaultRequestTimeout = Duration(seconds: 30);

  /// The Qdrant server address, without a trailing slash.
  final Uri baseUrl;

  /// The maximum duration for one HTTP request.
  final Duration timeout;

  late final QdrantTransport _transport;

  /// Releases HTTP resources held by this client.
  void close({bool force = false}) => _transport.close(force: force);

  static Uri _validateBaseUrl(Uri baseUrl) {
    if (!baseUrl.isAbsolute ||
        !{'http', 'https'}.contains(baseUrl.scheme) ||
        baseUrl.host.isEmpty) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must be an absolute HTTP or HTTPS URL.',
      );
    }
    if (baseUrl.hasQuery || baseUrl.hasFragment) {
      throw ArgumentError.value(
        baseUrl,
        'baseUrl',
        'must not contain a query or fragment.',
      );
    }

    final path = baseUrl.path;
    return baseUrl.replace(
      path: path == '/' ? '' : path.replaceFirst(RegExp(r'/$'), ''),
    );
  }

  static Duration _validateTimeout(Duration timeout) {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'must be positive.');
    }
    return timeout;
  }

  static String? _validateApiKey(String? apiKey) {
    if (apiKey != null && apiKey.isEmpty) {
      throw ArgumentError.value(apiKey, 'apiKey', 'must not be empty.');
    }
    return apiKey;
  }
}
