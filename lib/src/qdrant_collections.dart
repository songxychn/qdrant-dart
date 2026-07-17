part of 'qdrant_client.dart';

/// A collection's current status, vector configuration, and counts.
final class CollectionInfo {
  /// Creates collection details returned by Qdrant.
  const CollectionInfo({
    required this.name,
    required this.status,
    required this.vectors,
    required this.payloadIndexes,
    required this.pointsCount,
    required this.indexedVectorsCount,
    required this.segmentsCount,
  });

  /// The collection name used for the request.
  final String name;

  /// Qdrant's collection status, such as `green`.
  final String status;

  /// The collection's dense and sparse vector configuration.
  final CollectionVectors vectors;

  /// Payload indexes keyed by field name.
  final Map<String, PayloadIndexInfo> payloadIndexes;

  /// The current number of points in the collection.
  final int pointsCount;

  /// The current number of vectors indexed by Qdrant.
  final int indexedVectorsCount;

  /// The current number of Qdrant segments in the collection.
  final int segmentsCount;
}

/// Collection lifecycle operations for a [QdrantClient].
final class CollectionOperations {
  CollectionOperations._(this._transport);

  final QdrantTransport _transport;

  /// Creates [name] with the provided dense and sparse [vectors].
  Future<bool> create(String name, {required CollectionVectors vectors}) async {
    final response = await _transport.send(
      method: 'PUT',
      path: _collectionPath(name),
      body: vectors._toJson(),
    );
    return _booleanResult(response);
  }

  /// Retrieves current details for [name].
  Future<CollectionInfo> get(String name) async {
    final response = await _transport.send(
      method: 'GET',
      path: _collectionPath(name),
    );
    final result = _objectResult(response);
    final config = _jsonObject(result['config'], 'result.config');
    final params = _jsonObject(config['params'], 'result.config.params');
    return CollectionInfo(
      name: name,
      status: _string(result['status'], 'result.status'),
      vectors: CollectionVectors._fromJson(
        params['vectors'],
        params['sparse_vectors'],
      ),
      payloadIndexes: Map.unmodifiable(
        _jsonObject(
          result['payload_schema'],
          'result.payload_schema',
        ).map(
          (fieldName, value) => MapEntry(
            fieldName,
            PayloadIndexInfo._fromJson(value),
          ),
        ),
      ),
      pointsCount: _integer(result['points_count'], 'result.points_count'),
      indexedVectorsCount: _integer(
        result['indexed_vectors_count'],
        'result.indexed_vectors_count',
      ),
      segmentsCount:
          _integer(result['segments_count'], 'result.segments_count'),
    );
  }

  /// Lists all collection names visible to this Qdrant server.
  Future<List<String>> list() async {
    final response = await _transport.send(
      method: 'GET',
      path: Uri(path: 'collections'),
    );
    final collections = _objectResult(response)['collections'];
    if (collections is! List) {
      throw FormatException('Qdrant response has no collection list.');
    }
    return collections
        .map((collection) => _string(
              _jsonObject(collection, 'result.collections')['name'],
              'result.collections.name',
            ))
        .toList(growable: false);
  }

  /// Deletes [name] and all of its points.
  Future<bool> delete(String name) async {
    final response = await _transport.send(
      method: 'DELETE',
      path: _collectionPath(name),
    );
    return _booleanResult(response);
  }

  Uri _collectionPath(String name) {
    if (name.isEmpty) {
      throw ArgumentError.value(name, 'name', 'must not be empty.');
    }
    return Uri(pathSegments: ['collections', name]);
  }

  bool _booleanResult(QdrantResponse response) {
    final result = _responseObject(response)['result'];
    if (result is! bool) {
      throw FormatException('Qdrant response has no boolean result.');
    }
    return result;
  }

  Map<String, Object?> _objectResult(QdrantResponse response) =>
      _jsonObject(_responseObject(response)['result'], 'result');

  Map<String, Object?> _responseObject(QdrantResponse response) {
    final decoded = jsonDecode(response.body);
    return _jsonObject(decoded, 'response');
  }
}

Map<String, Object?> _jsonObject(Object? value, String name) {
  if (value is! Map) {
    throw FormatException('Qdrant response has no object at $name.');
  }
  return Map<String, Object?>.from(value);
}

String _string(Object? value, String name) {
  if (value is! String) {
    throw FormatException('Qdrant response has no string at $name.');
  }
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int) {
    throw FormatException('Qdrant response has no integer at $name.');
  }
  return value;
}
