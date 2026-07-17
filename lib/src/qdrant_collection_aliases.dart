part of 'qdrant_client.dart';

/// An alias and the collection it currently resolves to.
final class CollectionAlias {
  /// Creates an alias record returned by Qdrant.
  const CollectionAlias({
    required this.aliasName,
    required this.collectionName,
  });

  /// The alias used in place of a collection name.
  final String aliasName;

  /// The collection currently targeted by [aliasName].
  final String collectionName;
}

/// One action in an atomic collection-alias update.
final class CollectionAliasAction {
  CollectionAliasAction._(this._json);

  /// Creates [aliasName] for [collectionName].
  factory CollectionAliasAction.create({
    required String collectionName,
    required String aliasName,
  }) {
    _validateAliasName(collectionName, 'collectionName');
    _validateAliasName(aliasName, 'aliasName');
    return CollectionAliasAction._({
      'create_alias': {
        'collection_name': collectionName,
        'alias_name': aliasName,
      },
    });
  }

  /// Deletes [aliasName].
  factory CollectionAliasAction.delete(String aliasName) {
    _validateAliasName(aliasName, 'aliasName');
    return CollectionAliasAction._({
      'delete_alias': {'alias_name': aliasName},
    });
  }

  /// Renames [oldAliasName] to [newAliasName].
  factory CollectionAliasAction.rename({
    required String oldAliasName,
    required String newAliasName,
  }) {
    _validateAliasName(oldAliasName, 'oldAliasName');
    _validateAliasName(newAliasName, 'newAliasName');
    return CollectionAliasAction._({
      'rename_alias': {
        'old_alias_name': oldAliasName,
        'new_alias_name': newAliasName,
      },
    });
  }

  final Map<String, Object?> _json;
}

/// Collection-alias lifecycle operations for a [QdrantClient].
final class CollectionAliasOperations {
  CollectionAliasOperations._(this._transport);

  final QdrantTransport _transport;

  /// Lists all aliases, optionally limited to [collectionName].
  Future<List<CollectionAlias>> list({String? collectionName}) async {
    if (collectionName != null) {
      _validateAliasName(collectionName, 'collectionName');
    }
    final response = await _transport.send(
      method: 'GET',
      path: collectionName == null
          ? Uri(path: 'aliases')
          : Uri(pathSegments: ['collections', collectionName, 'aliases']),
    );
    final result = _jsonObject(
      _jsonObject(jsonDecode(response.body), 'response')['result'],
      'result',
    );
    final aliases = result['aliases'];
    if (aliases is! List) {
      throw FormatException('Qdrant response has no alias list.');
    }
    return aliases.map((value) {
      final alias = _jsonObject(value, 'result.aliases');
      return CollectionAlias(
        aliasName: _string(alias['alias_name'], 'result.aliases.alias_name'),
        collectionName: _string(
          alias['collection_name'],
          'result.aliases.collection_name',
        ),
      );
    }).toList(growable: false);
  }

  /// Applies [actions] atomically in their provided order.
  Future<bool> update(Iterable<CollectionAliasAction> actions) async {
    final actionList = actions.toList(growable: false);
    if (actionList.isEmpty) {
      throw ArgumentError.value(actions, 'actions', 'must not be empty.');
    }
    final response = await _transport.send(
      method: 'POST',
      path: Uri(pathSegments: ['collections', 'aliases']),
      body: {'actions': actionList.map((action) => action._json).toList()},
    );
    final result = _jsonObject(jsonDecode(response.body), 'response')['result'];
    if (result is! bool) {
      throw FormatException('Qdrant response has no boolean result.');
    }
    return result;
  }
}

void _validateAliasName(String value, String name) {
  if (value.isEmpty) {
    throw ArgumentError.value(value, name, 'must not be empty.');
  }
}
