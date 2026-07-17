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

/// Configuration for one dense vector in a collection.
final class DenseVectorParams {
  /// Creates dense-vector parameters.
  DenseVectorParams({required this.size, required this.distance}) {
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

  static DenseVectorParams _fromJson(Object? value) {
    final params = _jsonObject(value, 'dense vector parameters');
    final size = params['size'];
    if (size is! int) {
      throw FormatException('Qdrant response has no integer vector size.');
    }
    return DenseVectorParams(
      size: size,
      distance: Distance._fromJson(params['distance']),
    );
  }
}

/// Configuration for one sparse vector using Qdrant's defaults.
final class SparseVectorParams {
  /// Creates default sparse-vector parameters.
  const SparseVectorParams();

  Map<String, Object> _toJson() => const {};

  static SparseVectorParams _fromJson(Object? value) {
    _jsonObject(value, 'sparse vector parameters');
    return const SparseVectorParams();
  }
}

/// Dense and sparse vector configuration for a collection.
final class CollectionVectors {
  /// Configures one unnamed dense vector and optional named sparse vectors.
  CollectionVectors.dense(
    DenseVectorParams dense, {
    Map<String, SparseVectorParams> sparse = const {},
  })  : defaultDense = dense,
        namedDense = const {},
        sparse = Map.unmodifiable(_validateNamedMap(sparse, 'sparse'));

  /// Configures named dense and sparse vectors.
  CollectionVectors.named({
    Map<String, DenseVectorParams> dense = const {},
    Map<String, SparseVectorParams> sparse = const {},
  })  : defaultDense = null,
        namedDense = Map.unmodifiable(_validateNamedMap(dense, 'dense')),
        sparse = Map.unmodifiable(_validateNamedMap(sparse, 'sparse')) {
    if (namedDense.isEmpty && this.sparse.isEmpty) {
      throw ArgumentError('At least one named vector must be configured.');
    }
    final duplicateNames = namedDense.keys.toSet().intersection(
          this.sparse.keys.toSet(),
        );
    if (duplicateNames.isNotEmpty) {
      throw ArgumentError.value(
        duplicateNames.first,
        'vector name',
        'must not be used for both dense and sparse vectors.',
      );
    }
  }

  CollectionVectors._({
    required this.defaultDense,
    required this.namedDense,
    required this.sparse,
  });

  /// The unnamed dense-vector configuration, when single-vector mode is used.
  final DenseVectorParams? defaultDense;

  /// Named dense-vector configurations.
  final Map<String, DenseVectorParams> namedDense;

  /// Named sparse-vector configurations.
  final Map<String, SparseVectorParams> sparse;

  Map<String, Object> _toJson() => {
        'vectors': defaultDense?._toJson() ??
            namedDense.map((name, params) => MapEntry(name, params._toJson())),
        if (sparse.isNotEmpty)
          'sparse_vectors': sparse.map(
            (name, params) => MapEntry(name, params._toJson()),
          ),
      };

  static CollectionVectors _fromJson(
    Object? denseValue,
    Object? sparseValue,
  ) {
    final dense = _jsonObject(denseValue, 'vectors');
    final sparse = sparseValue == null
        ? const <String, SparseVectorParams>{}
        : _jsonObject(sparseValue, 'sparse_vectors').map(
            (name, params) => MapEntry(
              name,
              SparseVectorParams._fromJson(params),
            ),
          );
    if (dense.containsKey('size')) {
      return CollectionVectors._(
        defaultDense: DenseVectorParams._fromJson(dense),
        namedDense: const {},
        sparse: Map.unmodifiable(sparse),
      );
    }
    return CollectionVectors._(
      defaultDense: null,
      namedDense: Map.unmodifiable(
        dense.map(
          (name, params) => MapEntry(
            name,
            DenseVectorParams._fromJson(params),
          ),
        ),
      ),
      sparse: Map.unmodifiable(sparse),
    );
  }
}

/// A dense or sparse vector value.
sealed class VectorValue {
  const VectorValue();

  Object _toJson();

  static VectorValue _fromJson(Object? value) {
    if (value is List) {
      return DenseVector._fromJson(value);
    }
    final sparse = _jsonObject(value, 'sparse vector');
    return SparseVector._fromJson(sparse);
  }
}

/// A dense vector value.
final class DenseVector extends VectorValue {
  /// Creates a dense vector from finite numeric [values].
  DenseVector(Iterable<num> values)
      : values = List.unmodifiable(_validateDenseValues(values));

  /// Dense vector elements.
  final List<num> values;

  @override
  List<num> _toJson() => values;

  static DenseVector _fromJson(List<Object?> values) {
    if (values.any((value) => value is! num)) {
      throw FormatException('Qdrant response has an invalid dense vector.');
    }
    try {
      return DenseVector(values.cast<num>());
    } on ArgumentError {
      throw FormatException('Qdrant response has an invalid dense vector.');
    }
  }
}

/// A sparse vector represented by matching index and value lists.
final class SparseVector extends VectorValue {
  /// Creates a sparse vector.
  SparseVector({
    required Iterable<int> indices,
    required Iterable<num> values,
  })  : indices = List.unmodifiable(indices),
        values = List.unmodifiable(values) {
    if (this.indices.isEmpty || this.indices.length != this.values.length) {
      throw ArgumentError(
        'Sparse vector indices and values must be non-empty and equal length.',
      );
    }
    if (this.indices.any((index) => index < 0) ||
        this.indices.toSet().length != this.indices.length) {
      throw ArgumentError.value(
        this.indices,
        'indices',
        'must be unique non-negative integers.',
      );
    }
    if (this.values.any((value) => !value.isFinite)) {
      throw ArgumentError.value(
        this.values,
        'values',
        'must contain only finite numbers.',
      );
    }
  }

  /// Non-zero vector positions.
  final List<int> indices;

  /// Values at the matching [indices].
  final List<num> values;

  @override
  Map<String, Object> _toJson() => {
        'indices': indices,
        'values': values,
      };

  static SparseVector _fromJson(Map<String, Object?> value) {
    final indices = value['indices'];
    final values = value['values'];
    if (indices is! List ||
        indices.any((index) => index is! int) ||
        values is! List ||
        values.any((element) => element is! num)) {
      throw FormatException('Qdrant response has an invalid sparse vector.');
    }
    try {
      return SparseVector(
        indices: indices.cast<int>(),
        values: values.cast<num>(),
      );
    } on ArgumentError {
      throw FormatException('Qdrant response has an invalid sparse vector.');
    }
  }
}

/// Vectors stored on or returned for one point.
final class PointVectors {
  PointVectors._({required this.defaultDense, required this.named});

  /// The unnamed dense vector, when single-vector mode is used.
  final DenseVector? defaultDense;

  /// Named dense and sparse vectors.
  final Map<String, VectorValue> named;

  static PointVectors _dense(Iterable<num> values) => PointVectors._(
        defaultDense: DenseVector(values),
        named: const {},
      );

  static PointVectors _named(Map<String, VectorValue> vectors) {
    final validated = _validateNamedMap(vectors, 'vectors');
    if (validated.isEmpty) {
      throw ArgumentError.value(vectors, 'vectors', 'must not be empty.');
    }
    return PointVectors._(
      defaultDense: null,
      named: Map.unmodifiable(validated),
    );
  }

  Object _toJson() =>
      defaultDense?._toJson() ??
      named.map((name, vector) => MapEntry(name, vector._toJson()));

  static PointVectors _fromJson(Object? value) {
    if (value is List) {
      return PointVectors._(
        defaultDense: DenseVector._fromJson(value),
        named: const {},
      );
    }
    final named = _jsonObject(value, 'point vectors').map(
      (name, vector) => MapEntry(name, VectorValue._fromJson(vector)),
    );
    return PointVectors._(
      defaultDense: null,
      named: Map.unmodifiable(named),
    );
  }
}

/// Selects which vectors Qdrant should include in point responses.
final class VectorSelector {
  const VectorSelector._(this._value);

  /// Omits vectors from responses.
  const VectorSelector.none() : this._(false);

  /// Includes every vector in responses.
  const VectorSelector.all() : this._(true);

  /// Includes only the named vectors in [names].
  factory VectorSelector.named(Iterable<String> names) {
    final nameList = names.toList(growable: false);
    if (nameList.isEmpty) {
      throw ArgumentError.value(names, 'names', 'must not be empty.');
    }
    for (final name in nameList) {
      _validateVectorName(name, 'name');
    }
    if (nameList.toSet().length != nameList.length) {
      throw ArgumentError.value(names, 'names', 'must not contain duplicates.');
    }
    return VectorSelector._(List<String>.unmodifiable(nameList));
  }

  final Object _value;

  Object _toJson() => _value;
}

Map<String, T> _validateNamedMap<T>(Map<String, T> values, String name) {
  for (final key in values.keys) {
    _validateVectorName(key, name);
  }
  return values;
}

String _validateVectorName(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'must not contain empty names.');
  }
  return value;
}

List<num> _validateDenseValues(Iterable<num> values) {
  final result = values.toList(growable: false);
  if (result.isEmpty || result.any((value) => !value.isFinite)) {
    throw ArgumentError.value(
      values,
      'values',
      'must contain one or more finite numbers.',
    );
  }
  return result;
}
