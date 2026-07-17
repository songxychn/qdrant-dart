part of 'qdrant_client.dart';

/// Qdrant's simple payload field index types.
enum PayloadSchemaType {
  /// Exact string values.
  keyword('keyword'),

  /// Signed integer values.
  integer('integer'),

  /// Floating-point values.
  floatingPoint('float'),

  /// Geographic coordinates.
  geo('geo'),

  /// Full-text values.
  text('text'),

  /// Boolean values.
  boolean('bool'),

  /// Date-time values.
  dateTime('datetime'),

  /// UUID values.
  uuid('uuid');

  const PayloadSchemaType(this._value);

  final String _value;

  static PayloadSchemaType _fromJson(Object? value) => switch (value) {
        'keyword' => PayloadSchemaType.keyword,
        'integer' => PayloadSchemaType.integer,
        'float' => PayloadSchemaType.floatingPoint,
        'geo' => PayloadSchemaType.geo,
        'text' => PayloadSchemaType.text,
        'bool' => PayloadSchemaType.boolean,
        'datetime' => PayloadSchemaType.dateTime,
        'uuid' => PayloadSchemaType.uuid,
        _ => throw FormatException('Unsupported payload schema type: $value.'),
      };
}

/// Information reported for one payload field index.
final class PayloadIndexInfo {
  PayloadIndexInfo._({required this.schema, required this.pointsCount});

  /// The indexed field's data type.
  final PayloadSchemaType schema;

  /// Points currently covered by this index, when Qdrant reports the count.
  final int? pointsCount;

  static PayloadIndexInfo _fromJson(Object? value) {
    if (value is String) {
      return PayloadIndexInfo._(
        schema: PayloadSchemaType._fromJson(value),
        pointsCount: null,
      );
    }
    final object = _jsonObject(value, 'payload index');
    final points = object['points'];
    if (points != null && points is! int) {
      throw FormatException('Qdrant payload index has no integer point count.');
    }
    return PayloadIndexInfo._(
      schema: PayloadSchemaType._fromJson(object['data_type']),
      pointsCount: points as int?,
    );
  }
}

/// Payload-index lifecycle operations for a [QdrantClient].
final class PayloadIndexOperations {
  PayloadIndexOperations._(this._transport);

  final QdrantTransport _transport;

  /// Creates an index for [fieldName] before filtered data is ingested.
  Future<UpdateResult> create(
    String collectionName,
    String fieldName, {
    required PayloadSchemaType schema,
    bool wait = true,
  }) async {
    final response = await _transport.send(
      method: 'PUT',
      path: _indexPath(
        collectionName,
        queryParameters: {'wait': wait.toString()},
      ),
      body: {
        'field_name': _validateFieldName(fieldName),
        'field_schema': schema._value,
      },
    );
    return _updateResult(response);
  }

  /// Deletes the payload index for [fieldName].
  Future<UpdateResult> delete(
    String collectionName,
    String fieldName, {
    bool wait = true,
  }) async {
    final response = await _transport.send(
      method: 'DELETE',
      path: _indexPath(
        collectionName,
        fieldName: _validateFieldName(fieldName),
        queryParameters: {'wait': wait.toString()},
      ),
    );
    return _updateResult(response);
  }

  Uri _indexPath(
    String collectionName, {
    String? fieldName,
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
        'index',
        if (fieldName != null) fieldName,
      ],
      queryParameters: queryParameters,
    );
  }

  String _validateFieldName(String fieldName) {
    if (fieldName.isEmpty) {
      throw ArgumentError.value(
        fieldName,
        'fieldName',
        'must not be empty.',
      );
    }
    return fieldName;
  }
}
