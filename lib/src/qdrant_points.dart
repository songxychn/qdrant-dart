part of 'qdrant_client.dart';

/// A point to insert into or update in a Qdrant collection.
final class Point {
  /// Creates a point with a default dense [vector] and optional [payload].
  Point({
    required Object id,
    required List<num> vector,
    Map<String, Object?>? payload,
  })  : id = _validatePointId(id),
        vectors = PointVectors._dense(vector),
        payload = payload == null ? null : Map.unmodifiable(payload);

  /// Creates a point with named dense or sparse [vectors].
  Point.named({
    required Object id,
    required Map<String, VectorValue> vectors,
    Map<String, Object?>? payload,
  })  : id = _validatePointId(id),
        vectors = PointVectors._named(vectors),
        payload = payload == null ? null : Map.unmodifiable(payload);

  /// A non-negative integer or Qdrant UUID string.
  final Object id;

  /// The point's default dense vector, or `null` for named-vector points.
  List<num>? get vector => vectors.defaultDense?.values;

  /// The point's default or named vectors.
  final PointVectors vectors;

  /// JSON-compatible metadata associated with the point.
  final Map<String, Object?>? payload;

  Map<String, Object?> _toJson() => {
        'id': id,
        'vector': vectors._toJson(),
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
    required this.vectors,
    required this.payload,
  });

  /// The point's non-negative integer or UUID identifier.
  final Object id;

  /// The default dense vector, or `null` for named vectors or when omitted.
  List<num>? get vector => vectors?.defaultDense?.values;

  /// Returned default or named vectors, or `null` when they were not requested.
  final PointVectors? vectors;

  /// The point metadata, or `null` when payloads were not requested.
  final Map<String, Object?>? payload;

  static PointRecord _fromJson(Object? value) {
    final record = _jsonObject(value, 'result point');
    final id = _idFromJson(record['id']);

    final vectorValue = record['vector'];

    final payloadValue = record['payload'];
    return PointRecord._(
      id: id,
      vectors: vectorValue == null ? null : PointVectors._fromJson(vectorValue),
      payload: payloadValue == null
          ? null
          : Map.unmodifiable(_jsonObject(payloadValue, 'result point payload')),
    );
  }

  static Object _idFromJson(Object? value) => switch (value) {
        int value when value >= 0 => value,
        String value when value.isNotEmpty => value,
        _ => throw FormatException('Qdrant response has an invalid point ID.'),
      };
}

/// One page returned by Qdrant's point scroll endpoint.
final class ScrollPage {
  ScrollPage._({required this.points, required this.nextPageOffset});

  /// Points in this page, sorted by ID when no custom ordering is used.
  final List<PointRecord> points;

  /// The offset for the next page, or `null` when this is the last page.
  final Object? nextPageOffset;
}

/// A condition accepted in Qdrant filter clauses.
sealed class FilterCondition {
  const FilterCondition();

  Map<String, Object> _toJson();
}

/// A payload field condition used by Qdrant filters.
final class FieldCondition extends FilterCondition {
  /// Matches a keyword, integer, or boolean payload [value] at [key].
  FieldCondition.match(String key, Object value)
      : key = _validateKey(key),
        matchValue = _validateMatchValue(value),
        gt = null,
        gte = null,
        lt = null,
        lte = null,
        super();

  /// Matches numeric payload values within the provided bounds at [key].
  FieldCondition.range(
    String key, {
    this.gt,
    this.gte,
    this.lt,
    this.lte,
  })  : key = _validateKey(key),
        matchValue = null,
        super() {
    if (gt == null && gte == null && lt == null && lte == null) {
      throw ArgumentError('At least one range bound must be provided.');
    }
    for (final bound in [gt, gte, lt, lte]) {
      if (bound != null && !bound.isFinite) {
        throw ArgumentError.value(bound, 'range bound', 'must be finite.');
      }
    }
  }

  /// The payload key, including dot notation for nested fields.
  final String key;

  /// The exact match value, or `null` for a range condition.
  final Object? matchValue;

  /// Exclusive lower bound.
  final num? gt;

  /// Inclusive lower bound.
  final num? gte;

  /// Exclusive upper bound.
  final num? lt;

  /// Inclusive upper bound.
  final num? lte;

  @override
  Map<String, Object> _toJson() => {
        'key': key,
        if (matchValue != null)
          'match': {'value': matchValue!}
        else
          'range': {
            if (gt != null) 'gt': gt!,
            if (gte != null) 'gte': gte!,
            if (lt != null) 'lt': lt!,
            if (lte != null) 'lte': lte!,
          },
      };

  static String _validateKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError.value(key, 'key', 'must not be empty.');
    }
    return key;
  }

  static Object _validateMatchValue(Object value) {
    if (value is! String && value is! int && value is! bool) {
      throw ArgumentError.value(
        value,
        'value',
        'must be a string, integer, or boolean.',
      );
    }
    return value;
  }
}

/// Matches points whose IDs are included in [ids].
final class HasIdCondition extends FilterCondition {
  /// Creates a point-ID filter condition.
  HasIdCondition(Iterable<Object> ids)
      : ids = List.unmodifiable(ids.map(Point._validatePointId)) {
    if (this.ids.isEmpty) {
      throw ArgumentError.value(ids, 'ids', 'must not be empty.');
    }
  }

  /// Point IDs that satisfy this condition.
  final List<Object> ids;

  @override
  Map<String, Object> _toJson() => {'has_id': ids};
}

/// Qdrant payload filter clauses.
final class Filter extends FilterCondition {
  /// Creates a filter from AND [must], OR [should], and NOT [mustNot] clauses.
  Filter({
    Iterable<FilterCondition> must = const [],
    Iterable<FilterCondition> should = const [],
    Iterable<FilterCondition> mustNot = const [],
  })  : must = List.unmodifiable(must),
        should = List.unmodifiable(should),
        mustNot = List.unmodifiable(mustNot),
        super() {
    if (this.must.isEmpty && this.should.isEmpty && this.mustNot.isEmpty) {
      throw ArgumentError('At least one filter condition must be provided.');
    }
  }

  /// Conditions that must all match.
  final List<FilterCondition> must;

  /// Conditions where at least one must match.
  final List<FilterCondition> should;

  /// Conditions that must not match.
  final List<FilterCondition> mustNot;

  @override
  Map<String, Object> _toJson() => {
        if (must.isNotEmpty)
          'must': must.map((condition) => condition._toJson()).toList(),
        if (should.isNotEmpty)
          'should': should.map((condition) => condition._toJson()).toList(),
        if (mustNot.isNotEmpty)
          'must_not': mustNot.map((condition) => condition._toJson()).toList(),
      };
}

/// A point and similarity score returned by a dense-vector query.
final class ScoredPoint {
  ScoredPoint._({
    required this.id,
    required this.score,
    required this.vectors,
    required this.payload,
  });

  /// The point's non-negative integer or UUID identifier.
  final Object id;

  /// Qdrant's similarity score for this result.
  final double score;

  /// The default dense vector, or `null` for named vectors or when omitted.
  List<num>? get vector => vectors?.defaultDense?.values;

  /// Returned default or named vectors, or `null` when they were not requested.
  final PointVectors? vectors;

  /// The point metadata, or `null` when payloads were not requested.
  final Map<String, Object?>? payload;

  static ScoredPoint _fromJson(Object? value) {
    final object = _jsonObject(value, 'query result point');
    final record = PointRecord._fromJson(object);
    final score = object['score'];
    if (score is! num || !score.isFinite) {
      throw FormatException('Qdrant response has an invalid point score.');
    }
    return ScoredPoint._(
      id: record.id,
      score: score.toDouble(),
      vectors: record.vectors,
      payload: record.payload,
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
    return _updateResult(response);
  }

  /// Retrieves existing points matching [ids] from [collectionName].
  ///
  /// Payloads are returned by default. Use [withVectors] to request vectors.
  Future<List<PointRecord>> retrieve(
    String collectionName,
    Iterable<Object> ids, {
    bool withPayload = true,
    VectorSelector withVectors = const VectorSelector.none(),
  }) async {
    final idList = _pointIds(ids);

    final response = await _transport.send(
      method: 'POST',
      path: _pointsPath(collectionName),
      body: {
        'ids': idList,
        'with_payload': withPayload,
        'with_vector': withVectors._toJson(),
      },
    );
    final result = _result(response);
    if (result is! List) {
      throw FormatException('Qdrant response has no point list.');
    }
    return result.map(PointRecord._fromJson).toList(growable: false);
  }

  /// Deletes points matching [ids] from [collectionName].
  ///
  /// When [wait] is true, Qdrant waits until the deletion has been applied.
  Future<UpdateResult> delete(
    String collectionName,
    Iterable<Object> ids, {
    bool wait = true,
  }) async {
    final response = await _transport.send(
      method: 'POST',
      path: _pointsPath(
        collectionName,
        operation: 'delete',
        queryParameters: {'wait': wait.toString()},
      ),
      body: {'points': _pointIds(ids)},
    );
    return _updateResult(response);
  }

  /// Returns one ID-ordered page of points from [collectionName].
  Future<ScrollPage> scroll(
    String collectionName, {
    Object? offset,
    int limit = 10,
    Filter? filter,
    bool withPayload = true,
    VectorSelector withVectors = const VectorSelector.none(),
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive.');
    }
    final response = await _transport.send(
      method: 'POST',
      path: _pointsPath(collectionName, operation: 'scroll'),
      body: {
        if (offset != null) 'offset': Point._validatePointId(offset),
        'limit': limit,
        if (filter != null) 'filter': filter._toJson(),
        'with_payload': withPayload,
        'with_vector': withVectors._toJson(),
      },
    );
    final result = _jsonObject(_result(response), 'result');
    final points = result['points'];
    if (points is! List) {
      throw FormatException('Qdrant response has no scroll point list.');
    }
    final nextPageOffset = result['next_page_offset'];
    return ScrollPage._(
      points: points.map(PointRecord._fromJson).toList(growable: false),
      nextPageOffset: nextPageOffset == null
          ? null
          : PointRecord._idFromJson(nextPageOffset),
    );
  }

  /// Streams every point in [collectionName] using ID-based pagination.
  Stream<PointRecord> scrollAll(
    String collectionName, {
    int pageSize = 10,
    Filter? filter,
    bool withPayload = true,
    VectorSelector withVectors = const VectorSelector.none(),
  }) async* {
    Object? offset;
    do {
      final page = await scroll(
        collectionName,
        offset: offset,
        limit: pageSize,
        filter: filter,
        withPayload: withPayload,
        withVectors: withVectors,
      );
      for (final point in page.points) {
        yield point;
      }
      offset = page.nextPageOffset;
    } while (offset != null);
  }

  /// Finds points nearest to [vector], using the default vector or [using].
  Future<List<ScoredPoint>> query(
    String collectionName,
    VectorValue vector, {
    String? using,
    Filter? filter,
    int limit = 10,
    int offset = 0,
    num? scoreThreshold,
    bool withPayload = false,
    VectorSelector withVectors = const VectorSelector.none(),
  }) async {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', 'must be positive.');
    }
    if (offset < 0) {
      throw ArgumentError.value(offset, 'offset', 'must not be negative.');
    }
    if (scoreThreshold != null && !scoreThreshold.isFinite) {
      throw ArgumentError.value(
        scoreThreshold,
        'scoreThreshold',
        'must be finite.',
      );
    }
    if (using != null) {
      _validateVectorName(using, 'using');
    }
    final response = await _transport.send(
      method: 'POST',
      path: _pointsPath(collectionName, operation: 'query'),
      body: {
        'query': vector._toJson(),
        if (using != null) 'using': using,
        if (filter != null) 'filter': filter._toJson(),
        'limit': limit,
        'offset': offset,
        if (scoreThreshold != null) 'score_threshold': scoreThreshold,
        'with_payload': withPayload,
        'with_vector': withVectors._toJson(),
      },
    );
    final result = _jsonObject(_result(response), 'result');
    final points = result['points'];
    if (points is! List) {
      throw FormatException('Qdrant response has no query point list.');
    }
    return points.map(ScoredPoint._fromJson).toList(growable: false);
  }

  Uri _pointsPath(
    String collectionName, {
    String? operation,
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
      pathSegments: [
        'collections',
        collectionName,
        'points',
        if (operation != null) operation,
      ],
      queryParameters: queryParameters,
    );
  }

  List<Object> _pointIds(Iterable<Object> ids) {
    final idList = ids.map(Point._validatePointId).toList(growable: false);
    if (idList.isEmpty) {
      throw ArgumentError.value(ids, 'ids', 'must not be empty.');
    }
    return idList;
  }

  Object? _result(QdrantResponse response) =>
      _jsonObject(jsonDecode(response.body), 'response')['result'];
}

UpdateResult _updateResult(QdrantResponse response) {
  final result = _jsonObject(
    _jsonObject(jsonDecode(response.body), 'response')['result'],
    'result',
  );
  final operationId = result['operation_id'];
  if (operationId != null && operationId is! int) {
    throw FormatException('Qdrant response has no integer operation ID.');
  }
  return UpdateResult(
    operationId: operationId as int?,
    status: UpdateStatus._fromJson(result['status']),
  );
}
