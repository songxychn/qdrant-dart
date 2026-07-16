part of 'qdrant_client.dart';

/// Qdrant's distance metrics for dense vectors.
enum Distance {
  /// Cosine similarity.
  cosine('Cosine'),

  /// Dot-product similarity.
  dot('Dot'),

  /// Euclidean distance.
  euclid('Euclid'),

  /// Manhattan distance.
  manhattan('Manhattan');

  const Distance(this._value);

  final String _value;

  static Distance _fromJson(Object? value) => switch (value) {
        'Cosine' => Distance.cosine,
        'Dot' => Distance.dot,
        'Euclid' => Distance.euclid,
        'Manhattan' => Distance.manhattan,
        _ => throw FormatException('Unsupported Qdrant distance: $value.'),
      };
}

/// Parameters for Qdrant's default dense vector.
final class VectorParams {
  /// Creates dense-vector parameters for a collection.
  VectorParams({required this.size, required this.distance}) {
    if (size <= 0) {
      throw ArgumentError.value(size, 'size', 'must be positive.');
    }
  }

  /// The number of elements in every vector.
  final int size;

  /// The metric Qdrant uses to compare vectors.
  final Distance distance;

  Map<String, Object> _toJson() => {
        'size': size,
        'distance': distance._value,
      };

  static VectorParams _fromJson(Object? value) {
    final params = _jsonObject(value, 'vectors');
    final size = params['size'];
    if (size is! int) {
      throw FormatException('Qdrant response has no integer vector size.');
    }
    return VectorParams(
        size: size, distance: Distance._fromJson(params['distance']));
  }
}

/// A collection's current status, default vector configuration, and counts.
final class CollectionInfo {
  /// Creates collection details returned by Qdrant.
  const CollectionInfo({
    required this.name,
    required this.status,
    required this.vectors,
    required this.pointsCount,
    required this.indexedVectorsCount,
    required this.segmentsCount,
  });

  /// The collection name used for the request.
  final String name;

  /// Qdrant's collection status, such as `green`.
  final String status;

  /// The collection's default dense-vector configuration.
  final VectorParams vectors;

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

  /// Creates [name] with one default dense vector configuration.
  Future<bool> create(String name, {required VectorParams vectors}) async {
    final response = await _transport.send(
      method: 'PUT',
      path: _collectionPath(name),
      body: {'vectors': vectors._toJson()},
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
      vectors: VectorParams._fromJson(params['vectors']),
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
