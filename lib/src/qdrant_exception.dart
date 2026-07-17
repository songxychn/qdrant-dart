/// A failure returned by Qdrant or encountered while contacting it.
final class QdrantException implements Exception {
  /// Creates a Qdrant failure with request context.
  const QdrantException({
    required this.method,
    required this.uri,
    required this.message,
    this.statusCode,
    this.cause,
  });

  /// The HTTP method used for the failed request.
  final String method;

  /// The server URL used for the failed request.
  final Uri uri;

  /// Qdrant's error message when available.
  final String message;

  /// The HTTP status returned by Qdrant, or `null` for transport failures.
  final int? statusCode;

  /// The underlying transport or response-parsing failure, when available.
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'QdrantException: $method $uri$status: $message';
  }
}
