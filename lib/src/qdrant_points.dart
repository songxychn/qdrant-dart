part of 'qdrant_client.dart';

/// A point to insert into or update in a Qdrant collection.
final class Point {
  /// Creates a point with a default dense [vector] and optional [payload].
  Point({
    required Object id,
    required List<num> vector,
    Map<String, Object?>? payload,
  })  : id = _validatePointId(id),
        vector = List.unmodifiable(_validateVector(vector)),
        payload = payload == null ? null : Map.unmodifiable(payload);

  /// A non-negative integer or Qdrant UUID string.
  final Object id;

  /// The point's default dense vector.
  final List<num> vector;

  /// JSON-compatible metadata associated with the point.
  final Map<String, Object?>? payload;

  Map<String, Object?> _toJson() => {
        'id': id,
        'vector': vector,
        if (payload != null) 'payload': payload,
      };

  static Object _validatePointId(Object id) {
    if (id case int value when value >= 0) {
      return id;
    }
    if (id case String value when value.isNotEmpty) {
      return id;
    }
    throw ArgumentError.value(
      id,
      'id',
      'must be a non-negative integer or a non-empty UUID string.',
    );
  }

  static List<num> _validateVector(List<num> vector) {
    if (vector.isEmpty || vector.any((value) => !value.isFinite)) {
      throw ArgumentError.value(
        vector,
        'vector',
        'must contain one or more finite numbers.',
      );
    }
    return vector;
  }
}

/// The state of a Qdrant point update operation.
enum UpdateStatus {
  /// The update has been written to the write-ahead log.
  acknowledged,

  /// The update has been applied.
  completed,

  /// Qdrant accepted the update but did not apply it before the wait timeout.
  waitTimeout;

  static UpdateStatus _fromJson(Object? value) => switch (value) {
        'acknowledged' => UpdateStatus.acknowledged,
        'completed' => UpdateStatus.completed,
        'wait_timeout' => UpdateStatus.waitTimeout,
        _ => throw FormatException('Unsupported Qdrant update status: $value.'),
      };
}

/// Qdrant's result for a point update operation.
final class UpdateResult {
  /// Creates a point update result returned by Qdrant.
  const UpdateResult({required this.operationId, required this.status});

  /// Qdrant's sequential operation number, when one was assigned.
  final int? operationId;

  /// The current state of the update.
  final UpdateStatus status;
}

/// A point returned by Qdrant.
final class PointRecord {
  PointRecord._({
    required this.id,
    required this.vector,
    required this.payload,
  });

  /// The point's non-negative integer or UUID identifier.
  final Object id;

  /// The default dense vector, or `null` when vectors were not requested.
  final List<num>? vector;

  /// The point metadata, or `null` when payloads were not requested.
  final Map<String, Object?>? payload;

  static PointRecord _fromJson(Object? value) {
    final record = _jsonObject(value, 'result point');
    final id = switch (record['id']) {
      int value when value >= 0 => value,
      String value when value.isNotEmpty => value,
      _ => throw FormatException('Qdrant response has an invalid point ID.'),
    };

    final vectorValue = record['vector'];
    List<num>? vector;
    if (vectorValue != null) {
      if (vectorValue is! List ||
          vectorValue.isEmpty ||
          vectorValue.any((value) => value is! num || !value.isFinite)) {
        throw FormatException(
          'Qdrant response has an invalid default dense vector.',
        );
      }
      vector = List<num>.unmodifiable(vectorValue);
    }

    final payloadValue = record['payload'];
    return PointRecord._(
      id: id,
      vector: vector,
      payload: payloadValue == null
          ? null
          : Map.unmodifiable(_jsonObject(payloadValue, 'result point payload')),
    );
  }
}

/// Point operations for a [QdrantClient].
final class PointOperations {
  PointOperations._(this._transport);

  final QdrantTransport _transport;

  /// Inserts or replaces [points] in [collectionName].
  ///
  /// When [wait] is true, Qdrant waits until the update has been applied.
  Future<UpdateResult> upsert(
    String collectionName,
    Iterable<Point> points, {
    bool wait = true,
  }) async {
    final pointList = points.toList(growable: false);
    if (pointList.isEmpty) {
      throw ArgumentError.value(points, 'points', 'must not be empty.');
    }

    final response = await _transport.send(
      method: 'PUT',
      path: _pointsPath(
        collectionName,
        queryParameters: {'wait': wait.toString()},
      ),
      body: {
        'points': pointList.map((point) => point._toJson()).toList(),
      },
    );
    final result = _jsonObject(_result(response), 'result');
    final operationId = result['operation_id'];
    if (operationId != null && operationId is! int) {
      throw FormatException(
        'Qdrant response has no integer operation ID.',
      );
    }
    return UpdateResult(
      operationId: operationId as int?,
      status: UpdateStatus._fromJson(result['status']),
    );
  }

  /// Retrieves existing points matching [ids] from [collectionName].
  ///
  /// Payloads are returned by default. Set [withVector] to true when the
  /// default dense vectors are also needed.
  Future<List<PointRecord>> retrieve(
    String collectionName,
    Iterable<Object> ids, {
    bool withPayload = true,
    bool withVector = false,
  }) async {
    final idList = ids.map(Point._validatePointId).toList(growable: false);
    if (idList.isEmpty) {
      throw ArgumentError.value(ids, 'ids', 'must not be empty.');
    }

    final response = await _transport.send(
      method: 'POST',
      path: _pointsPath(collectionName),
      body: {
        'ids': idList,
        'with_payload': withPayload,
        'with_vector': withVector,
      },
    );
    final result = _result(response);
    if (result is! List) {
      throw FormatException('Qdrant response has no point list.');
    }
    return result.map(PointRecord._fromJson).toList(growable: false);
  }

  Uri _pointsPath(
    String collectionName, {
    Map<String, String>? queryParameters,
  }) {
    if (collectionName.isEmpty) {
      throw ArgumentError.value(
        collectionName,
        'collectionName',
        'must not be empty.',
      );
    }
    return Uri(
      pathSegments: ['collections', collectionName, 'points'],
      queryParameters: queryParameters,
    );
  }

  Object? _result(QdrantResponse response) =>
      _jsonObject(jsonDecode(response.body), 'response')['result'];
}
