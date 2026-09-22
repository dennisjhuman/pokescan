// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $CardsCacheTable extends CardsCache
    with TableInfo<$CardsCacheTable, CardsCacheData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CardsCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<int> fetchedAt = GeneratedColumn<int>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previousJsonMeta = const VerificationMeta(
    'previousJson',
  );
  @override
  late final GeneratedColumn<String> previousJson = GeneratedColumn<String>(
    'previous_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _previousFetchedAtMeta = const VerificationMeta(
    'previousFetchedAt',
  );
  @override
  late final GeneratedColumn<int> previousFetchedAt = GeneratedColumn<int>(
    'previous_fetched_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    json,
    fetchedAt,
    previousJson,
    previousFetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cards_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<CardsCacheData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    if (data.containsKey('previous_json')) {
      context.handle(
        _previousJsonMeta,
        previousJson.isAcceptableOrUnknown(
          data['previous_json']!,
          _previousJsonMeta,
        ),
      );
    }
    if (data.containsKey('previous_fetched_at')) {
      context.handle(
        _previousFetchedAtMeta,
        previousFetchedAt.isAcceptableOrUnknown(
          data['previous_fetched_at']!,
          _previousFetchedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CardsCacheData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CardsCacheData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fetched_at'],
      )!,
      previousJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}previous_json'],
      ),
      previousFetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}previous_fetched_at'],
      ),
    );
  }

  @override
  $CardsCacheTable createAlias(String alias) {
    return $CardsCacheTable(attachedDatabase, alias);
  }
}

class CardsCacheData extends DataClass implements Insertable<CardsCacheData> {
  final String id;
  final String json;
  final int fetchedAt;

  /// The response this row replaced, or null if it has only been fetched once.
  final String? previousJson;
  final int? previousFetchedAt;
  const CardsCacheData({
    required this.id,
    required this.json,
    required this.fetchedAt,
    this.previousJson,
    this.previousFetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    map['fetched_at'] = Variable<int>(fetchedAt);
    if (!nullToAbsent || previousJson != null) {
      map['previous_json'] = Variable<String>(previousJson);
    }
    if (!nullToAbsent || previousFetchedAt != null) {
      map['previous_fetched_at'] = Variable<int>(previousFetchedAt);
    }
    return map;
  }

  CardsCacheCompanion toCompanion(bool nullToAbsent) {
    return CardsCacheCompanion(
      id: Value(id),
      json: Value(json),
      fetchedAt: Value(fetchedAt),
      previousJson: previousJson == null && nullToAbsent
          ? const Value.absent()
          : Value(previousJson),
      previousFetchedAt: previousFetchedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(previousFetchedAt),
    );
  }

  factory CardsCacheData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CardsCacheData(
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      fetchedAt: serializer.fromJson<int>(json['fetchedAt']),
      previousJson: serializer.fromJson<String?>(json['previousJson']),
      previousFetchedAt: serializer.fromJson<int?>(json['previousFetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
      'fetchedAt': serializer.toJson<int>(fetchedAt),
      'previousJson': serializer.toJson<String?>(previousJson),
      'previousFetchedAt': serializer.toJson<int?>(previousFetchedAt),
    };
  }

  CardsCacheData copyWith({
    String? id,
    String? json,
    int? fetchedAt,
    Value<String?> previousJson = const Value.absent(),
    Value<int?> previousFetchedAt = const Value.absent(),
  }) => CardsCacheData(
    id: id ?? this.id,
    json: json ?? this.json,
    fetchedAt: fetchedAt ?? this.fetchedAt,
    previousJson: previousJson.present ? previousJson.value : this.previousJson,
    previousFetchedAt: previousFetchedAt.present
        ? previousFetchedAt.value
        : this.previousFetchedAt,
  );
  CardsCacheData copyWithCompanion(CardsCacheCompanion data) {
    return CardsCacheData(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
      previousJson: data.previousJson.present
          ? data.previousJson.value
          : this.previousJson,
      previousFetchedAt: data.previousFetchedAt.present
          ? data.previousFetchedAt.value
          : this.previousFetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CardsCacheData(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('previousJson: $previousJson, ')
          ..write('previousFetchedAt: $previousFetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, json, fetchedAt, previousJson, previousFetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CardsCacheData &&
          other.id == this.id &&
          other.json == this.json &&
          other.fetchedAt == this.fetchedAt &&
          other.previousJson == this.previousJson &&
          other.previousFetchedAt == this.previousFetchedAt);
}

class CardsCacheCompanion extends UpdateCompanion<CardsCacheData> {
  final Value<String> id;
  final Value<String> json;
  final Value<int> fetchedAt;
  final Value<String?> previousJson;
  final Value<int?> previousFetchedAt;
  final Value<int> rowid;
  const CardsCacheCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.previousJson = const Value.absent(),
    this.previousFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CardsCacheCompanion.insert({
    required String id,
    required String json,
    required int fetchedAt,
    this.previousJson = const Value.absent(),
    this.previousFetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       json = Value(json),
       fetchedAt = Value(fetchedAt);
  static Insertable<CardsCacheData> custom({
    Expression<String>? id,
    Expression<String>? json,
    Expression<int>? fetchedAt,
    Expression<String>? previousJson,
    Expression<int>? previousFetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (previousJson != null) 'previous_json': previousJson,
      if (previousFetchedAt != null) 'previous_fetched_at': previousFetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CardsCacheCompanion copyWith({
    Value<String>? id,
    Value<String>? json,
    Value<int>? fetchedAt,
    Value<String?>? previousJson,
    Value<int?>? previousFetchedAt,
    Value<int>? rowid,
  }) {
    return CardsCacheCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      previousJson: previousJson ?? this.previousJson,
      previousFetchedAt: previousFetchedAt ?? this.previousFetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<int>(fetchedAt.value);
    }
    if (previousJson.present) {
      map['previous_json'] = Variable<String>(previousJson.value);
    }
    if (previousFetchedAt.present) {
      map['previous_fetched_at'] = Variable<int>(previousFetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CardsCacheCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('previousJson: $previousJson, ')
          ..write('previousFetchedAt: $previousFetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CollectionItemsTable extends CollectionItems
    with TableInfo<$CollectionItemsTable, CollectionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CollectionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _cardIdMeta = const VerificationMeta('cardId');
  @override
  late final GeneratedColumn<String> cardId = GeneratedColumn<String>(
    'card_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES cards_cache (id)',
    ),
  );
  static const VerificationMeta _variantMeta = const VerificationMeta(
    'variant',
  );
  @override
  late final GeneratedColumn<String> variant = GeneratedColumn<String>(
    'variant',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<int> quantity = GeneratedColumn<int>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _conditionMeta = const VerificationMeta(
    'condition',
  );
  @override
  late final GeneratedColumn<String> condition = GeneratedColumn<String>(
    'condition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('NM'),
  );
  static const VerificationMeta _languageMeta = const VerificationMeta(
    'language',
  );
  @override
  late final GeneratedColumn<String> language = GeneratedColumn<String>(
    'language',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('en'),
  );
  static const VerificationMeta _scanPathMeta = const VerificationMeta(
    'scanPath',
  );
  @override
  late final GeneratedColumn<String> scanPath = GeneratedColumn<String>(
    'scan_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _acquiredAtMeta = const VerificationMeta(
    'acquiredAt',
  );
  @override
  late final GeneratedColumn<int> acquiredAt = GeneratedColumn<int>(
    'acquired_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pricePaidMeta = const VerificationMeta(
    'pricePaid',
  );
  @override
  late final GeneratedColumn<double> pricePaid = GeneratedColumn<double>(
    'price_paid',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    cardId,
    variant,
    quantity,
    condition,
    language,
    scanPath,
    notes,
    acquiredAt,
    pricePaid,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'collection_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<CollectionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('card_id')) {
      context.handle(
        _cardIdMeta,
        cardId.isAcceptableOrUnknown(data['card_id']!, _cardIdMeta),
      );
    } else if (isInserting) {
      context.missing(_cardIdMeta);
    }
    if (data.containsKey('variant')) {
      context.handle(
        _variantMeta,
        variant.isAcceptableOrUnknown(data['variant']!, _variantMeta),
      );
    } else if (isInserting) {
      context.missing(_variantMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('condition')) {
      context.handle(
        _conditionMeta,
        condition.isAcceptableOrUnknown(data['condition']!, _conditionMeta),
      );
    }
    if (data.containsKey('language')) {
      context.handle(
        _languageMeta,
        language.isAcceptableOrUnknown(data['language']!, _languageMeta),
      );
    }
    if (data.containsKey('scan_path')) {
      context.handle(
        _scanPathMeta,
        scanPath.isAcceptableOrUnknown(data['scan_path']!, _scanPathMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('acquired_at')) {
      context.handle(
        _acquiredAtMeta,
        acquiredAt.isAcceptableOrUnknown(data['acquired_at']!, _acquiredAtMeta),
      );
    }
    if (data.containsKey('price_paid')) {
      context.handle(
        _pricePaidMeta,
        pricePaid.isAcceptableOrUnknown(data['price_paid']!, _pricePaidMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CollectionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CollectionItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      cardId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_id'],
      )!,
      variant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}variant'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quantity'],
      )!,
      condition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}condition'],
      )!,
      language: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}language'],
      )!,
      scanPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scan_path'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      acquiredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}acquired_at'],
      ),
      pricePaid: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_paid'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $CollectionItemsTable createAlias(String alias) {
    return $CollectionItemsTable(attachedDatabase, alias);
  }
}

class CollectionItem extends DataClass implements Insertable<CollectionItem> {
  final int id;
  final String cardId;
  final String variant;
  final int quantity;
  final String condition;
  final String language;
  final String? scanPath;
  final String? notes;
  final int? acquiredAt;
  final double? pricePaid;
  final int addedAt;
  const CollectionItem({
    required this.id,
    required this.cardId,
    required this.variant,
    required this.quantity,
    required this.condition,
    required this.language,
    this.scanPath,
    this.notes,
    this.acquiredAt,
    this.pricePaid,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['card_id'] = Variable<String>(cardId);
    map['variant'] = Variable<String>(variant);
    map['quantity'] = Variable<int>(quantity);
    map['condition'] = Variable<String>(condition);
    map['language'] = Variable<String>(language);
    if (!nullToAbsent || scanPath != null) {
      map['scan_path'] = Variable<String>(scanPath);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || acquiredAt != null) {
      map['acquired_at'] = Variable<int>(acquiredAt);
    }
    if (!nullToAbsent || pricePaid != null) {
      map['price_paid'] = Variable<double>(pricePaid);
    }
    map['added_at'] = Variable<int>(addedAt);
    return map;
  }

  CollectionItemsCompanion toCompanion(bool nullToAbsent) {
    return CollectionItemsCompanion(
      id: Value(id),
      cardId: Value(cardId),
      variant: Value(variant),
      quantity: Value(quantity),
      condition: Value(condition),
      language: Value(language),
      scanPath: scanPath == null && nullToAbsent
          ? const Value.absent()
          : Value(scanPath),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      acquiredAt: acquiredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(acquiredAt),
      pricePaid: pricePaid == null && nullToAbsent
          ? const Value.absent()
          : Value(pricePaid),
      addedAt: Value(addedAt),
    );
  }

  factory CollectionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CollectionItem(
      id: serializer.fromJson<int>(json['id']),
      cardId: serializer.fromJson<String>(json['cardId']),
      variant: serializer.fromJson<String>(json['variant']),
      quantity: serializer.fromJson<int>(json['quantity']),
      condition: serializer.fromJson<String>(json['condition']),
      language: serializer.fromJson<String>(json['language']),
      scanPath: serializer.fromJson<String?>(json['scanPath']),
      notes: serializer.fromJson<String?>(json['notes']),
      acquiredAt: serializer.fromJson<int?>(json['acquiredAt']),
      pricePaid: serializer.fromJson<double?>(json['pricePaid']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'cardId': serializer.toJson<String>(cardId),
      'variant': serializer.toJson<String>(variant),
      'quantity': serializer.toJson<int>(quantity),
      'condition': serializer.toJson<String>(condition),
      'language': serializer.toJson<String>(language),
      'scanPath': serializer.toJson<String?>(scanPath),
      'notes': serializer.toJson<String?>(notes),
      'acquiredAt': serializer.toJson<int?>(acquiredAt),
      'pricePaid': serializer.toJson<double?>(pricePaid),
      'addedAt': serializer.toJson<int>(addedAt),
    };
  }

  CollectionItem copyWith({
    int? id,
    String? cardId,
    String? variant,
    int? quantity,
    String? condition,
    String? language,
    Value<String?> scanPath = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<int?> acquiredAt = const Value.absent(),
    Value<double?> pricePaid = const Value.absent(),
    int? addedAt,
  }) => CollectionItem(
    id: id ?? this.id,
    cardId: cardId ?? this.cardId,
    variant: variant ?? this.variant,
    quantity: quantity ?? this.quantity,
    condition: condition ?? this.condition,
    language: language ?? this.language,
    scanPath: scanPath.present ? scanPath.value : this.scanPath,
    notes: notes.present ? notes.value : this.notes,
    acquiredAt: acquiredAt.present ? acquiredAt.value : this.acquiredAt,
    pricePaid: pricePaid.present ? pricePaid.value : this.pricePaid,
    addedAt: addedAt ?? this.addedAt,
  );
  CollectionItem copyWithCompanion(CollectionItemsCompanion data) {
    return CollectionItem(
      id: data.id.present ? data.id.value : this.id,
      cardId: data.cardId.present ? data.cardId.value : this.cardId,
      variant: data.variant.present ? data.variant.value : this.variant,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      condition: data.condition.present ? data.condition.value : this.condition,
      language: data.language.present ? data.language.value : this.language,
      scanPath: data.scanPath.present ? data.scanPath.value : this.scanPath,
      notes: data.notes.present ? data.notes.value : this.notes,
      acquiredAt: data.acquiredAt.present
          ? data.acquiredAt.value
          : this.acquiredAt,
      pricePaid: data.pricePaid.present ? data.pricePaid.value : this.pricePaid,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItem(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('variant: $variant, ')
          ..write('quantity: $quantity, ')
          ..write('condition: $condition, ')
          ..write('language: $language, ')
          ..write('scanPath: $scanPath, ')
          ..write('notes: $notes, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('pricePaid: $pricePaid, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    cardId,
    variant,
    quantity,
    condition,
    language,
    scanPath,
    notes,
    acquiredAt,
    pricePaid,
    addedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CollectionItem &&
          other.id == this.id &&
          other.cardId == this.cardId &&
          other.variant == this.variant &&
          other.quantity == this.quantity &&
          other.condition == this.condition &&
          other.language == this.language &&
          other.scanPath == this.scanPath &&
          other.notes == this.notes &&
          other.acquiredAt == this.acquiredAt &&
          other.pricePaid == this.pricePaid &&
          other.addedAt == this.addedAt);
}

class CollectionItemsCompanion extends UpdateCompanion<CollectionItem> {
  final Value<int> id;
  final Value<String> cardId;
  final Value<String> variant;
  final Value<int> quantity;
  final Value<String> condition;
  final Value<String> language;
  final Value<String?> scanPath;
  final Value<String?> notes;
  final Value<int?> acquiredAt;
  final Value<double?> pricePaid;
  final Value<int> addedAt;
  const CollectionItemsCompanion({
    this.id = const Value.absent(),
    this.cardId = const Value.absent(),
    this.variant = const Value.absent(),
    this.quantity = const Value.absent(),
    this.condition = const Value.absent(),
    this.language = const Value.absent(),
    this.scanPath = const Value.absent(),
    this.notes = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.pricePaid = const Value.absent(),
    this.addedAt = const Value.absent(),
  });
  CollectionItemsCompanion.insert({
    this.id = const Value.absent(),
    required String cardId,
    required String variant,
    this.quantity = const Value.absent(),
    this.condition = const Value.absent(),
    this.language = const Value.absent(),
    this.scanPath = const Value.absent(),
    this.notes = const Value.absent(),
    this.acquiredAt = const Value.absent(),
    this.pricePaid = const Value.absent(),
    required int addedAt,
  }) : cardId = Value(cardId),
       variant = Value(variant),
       addedAt = Value(addedAt);
  static Insertable<CollectionItem> custom({
    Expression<int>? id,
    Expression<String>? cardId,
    Expression<String>? variant,
    Expression<int>? quantity,
    Expression<String>? condition,
    Expression<String>? language,
    Expression<String>? scanPath,
    Expression<String>? notes,
    Expression<int>? acquiredAt,
    Expression<double>? pricePaid,
    Expression<int>? addedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (cardId != null) 'card_id': cardId,
      if (variant != null) 'variant': variant,
      if (quantity != null) 'quantity': quantity,
      if (condition != null) 'condition': condition,
      if (language != null) 'language': language,
      if (scanPath != null) 'scan_path': scanPath,
      if (notes != null) 'notes': notes,
      if (acquiredAt != null) 'acquired_at': acquiredAt,
      if (pricePaid != null) 'price_paid': pricePaid,
      if (addedAt != null) 'added_at': addedAt,
    });
  }

  CollectionItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? cardId,
    Value<String>? variant,
    Value<int>? quantity,
    Value<String>? condition,
    Value<String>? language,
    Value<String?>? scanPath,
    Value<String?>? notes,
    Value<int?>? acquiredAt,
    Value<double?>? pricePaid,
    Value<int>? addedAt,
  }) {
    return CollectionItemsCompanion(
      id: id ?? this.id,
      cardId: cardId ?? this.cardId,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
      condition: condition ?? this.condition,
      language: language ?? this.language,
      scanPath: scanPath ?? this.scanPath,
      notes: notes ?? this.notes,
      acquiredAt: acquiredAt ?? this.acquiredAt,
      pricePaid: pricePaid ?? this.pricePaid,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (cardId.present) {
      map['card_id'] = Variable<String>(cardId.value);
    }
    if (variant.present) {
      map['variant'] = Variable<String>(variant.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<int>(quantity.value);
    }
    if (condition.present) {
      map['condition'] = Variable<String>(condition.value);
    }
    if (language.present) {
      map['language'] = Variable<String>(language.value);
    }
    if (scanPath.present) {
      map['scan_path'] = Variable<String>(scanPath.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (acquiredAt.present) {
      map['acquired_at'] = Variable<int>(acquiredAt.value);
    }
    if (pricePaid.present) {
      map['price_paid'] = Variable<double>(pricePaid.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CollectionItemsCompanion(')
          ..write('id: $id, ')
          ..write('cardId: $cardId, ')
          ..write('variant: $variant, ')
          ..write('quantity: $quantity, ')
          ..write('condition: $condition, ')
          ..write('language: $language, ')
          ..write('scanPath: $scanPath, ')
          ..write('notes: $notes, ')
          ..write('acquiredAt: $acquiredAt, ')
          ..write('pricePaid: $pricePaid, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }
}

class $SetListsTable extends SetLists with TableInfo<$SetListsTable, SetList> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SetListsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
    'lang',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _checkedAtMeta = const VerificationMeta(
    'checkedAt',
  );
  @override
  late final GeneratedColumn<int> checkedAt = GeneratedColumn<int>(
    'checked_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [lang, json, checkedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'set_lists';
  @override
  VerificationContext validateIntegrity(
    Insertable<SetList> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('lang')) {
      context.handle(
        _langMeta,
        lang.isAcceptableOrUnknown(data['lang']!, _langMeta),
      );
    } else if (isInserting) {
      context.missing(_langMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('checked_at')) {
      context.handle(
        _checkedAtMeta,
        checkedAt.isAcceptableOrUnknown(data['checked_at']!, _checkedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_checkedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lang};
  @override
  SetList map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SetList(
      lang: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lang'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
      checkedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}checked_at'],
      )!,
    );
  }

  @override
  $SetListsTable createAlias(String alias) {
    return $SetListsTable(attachedDatabase, alias);
  }
}

class SetList extends DataClass implements Insertable<SetList> {
  final String lang;
  final String json;

  /// When TCGdex was last asked, epoch ms. Drives the once-a-day check.
  final int checkedAt;
  const SetList({
    required this.lang,
    required this.json,
    required this.checkedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['lang'] = Variable<String>(lang);
    map['json'] = Variable<String>(json);
    map['checked_at'] = Variable<int>(checkedAt);
    return map;
  }

  SetListsCompanion toCompanion(bool nullToAbsent) {
    return SetListsCompanion(
      lang: Value(lang),
      json: Value(json),
      checkedAt: Value(checkedAt),
    );
  }

  factory SetList.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SetList(
      lang: serializer.fromJson<String>(json['lang']),
      json: serializer.fromJson<String>(json['json']),
      checkedAt: serializer.fromJson<int>(json['checkedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'lang': serializer.toJson<String>(lang),
      'json': serializer.toJson<String>(json),
      'checkedAt': serializer.toJson<int>(checkedAt),
    };
  }

  SetList copyWith({String? lang, String? json, int? checkedAt}) => SetList(
    lang: lang ?? this.lang,
    json: json ?? this.json,
    checkedAt: checkedAt ?? this.checkedAt,
  );
  SetList copyWithCompanion(SetListsCompanion data) {
    return SetList(
      lang: data.lang.present ? data.lang.value : this.lang,
      json: data.json.present ? data.json.value : this.json,
      checkedAt: data.checkedAt.present ? data.checkedAt.value : this.checkedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SetList(')
          ..write('lang: $lang, ')
          ..write('json: $json, ')
          ..write('checkedAt: $checkedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(lang, json, checkedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SetList &&
          other.lang == this.lang &&
          other.json == this.json &&
          other.checkedAt == this.checkedAt);
}

class SetListsCompanion extends UpdateCompanion<SetList> {
  final Value<String> lang;
  final Value<String> json;
  final Value<int> checkedAt;
  final Value<int> rowid;
  const SetListsCompanion({
    this.lang = const Value.absent(),
    this.json = const Value.absent(),
    this.checkedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SetListsCompanion.insert({
    required String lang,
    required String json,
    required int checkedAt,
    this.rowid = const Value.absent(),
  }) : lang = Value(lang),
       json = Value(json),
       checkedAt = Value(checkedAt);
  static Insertable<SetList> custom({
    Expression<String>? lang,
    Expression<String>? json,
    Expression<int>? checkedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (lang != null) 'lang': lang,
      if (json != null) 'json': json,
      if (checkedAt != null) 'checked_at': checkedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SetListsCompanion copyWith({
    Value<String>? lang,
    Value<String>? json,
    Value<int>? checkedAt,
    Value<int>? rowid,
  }) {
    return SetListsCompanion(
      lang: lang ?? this.lang,
      json: json ?? this.json,
      checkedAt: checkedAt ?? this.checkedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (checkedAt.present) {
      map['checked_at'] = Variable<int>(checkedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SetListsCompanion(')
          ..write('lang: $lang, ')
          ..write('json: $json, ')
          ..write('checkedAt: $checkedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $CardsCacheTable cardsCache = $CardsCacheTable(this);
  late final $CollectionItemsTable collectionItems = $CollectionItemsTable(
    this,
  );
  late final $SetListsTable setLists = $SetListsTable(this);
  late final CardCacheDao cardCacheDao = CardCacheDao(this as AppDatabase);
  late final CollectionDao collectionDao = CollectionDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    cardsCache,
    collectionItems,
    setLists,
  ];
}

typedef $$CardsCacheTableCreateCompanionBuilder = CardsCacheCompanion Function({
  required String id,
  required String json,
  required int fetchedAt,
  Value<String?> previousJson,
  Value<int?> previousFetchedAt,
  Value<int> rowid,
});
typedef $$CardsCacheTableUpdateCompanionBuilder = CardsCacheCompanion Function({
  Value<String> id,
  Value<String> json,
  Value<int> fetchedAt,
  Value<String?> previousJson,
  Value<int?> previousFetchedAt,
  Value<int> rowid,
});

final class $$CardsCacheTableReferences
    extends BaseReferences<_$AppDatabase, $CardsCacheTable, CardsCacheData> {
  $$CardsCacheTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$CollectionItemsTable, List<CollectionItem>>
  _collectionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.collectionItems,
    aliasName: 'cards_cache__id__collection_items__card_id',
  );

  $$CollectionItemsTableProcessedTableManager get collectionItemsRefs {
    final manager = $$CollectionItemsTableTableManager(
      $_db,
      $_db.collectionItems,
    ).filter((f) => f.cardId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _collectionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CardsCacheTableFilterComposer
    extends Composer<_$AppDatabase, $CardsCacheTable> {
  $$CardsCacheTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previousJson => $composableBuilder(
    column: $table.previousJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get previousFetchedAt => $composableBuilder(
    column: $table.previousFetchedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> collectionItemsRefs(
    Expression<bool> Function($$CollectionItemsTableFilterComposer f) f,
  ) {
    final $$CollectionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableFilterComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $CardsCacheTable> {
  $$CardsCacheTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previousJson => $composableBuilder(
    column: $table.previousJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get previousFetchedAt => $composableBuilder(
    column: $table.previousFetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CardsCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $CardsCacheTable> {
  $$CardsCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);

  GeneratedColumn<String> get previousJson => $composableBuilder(
    column: $table.previousJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get previousFetchedAt => $composableBuilder(
    column: $table.previousFetchedAt,
    builder: (column) => column,
  );

  Expression<T> collectionItemsRefs<T extends Object>(
    Expression<T> Function($$CollectionItemsTableAnnotationComposer a) f,
  ) {
    final $$CollectionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.collectionItems,
      getReferencedColumn: (t) => t.cardId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CollectionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.collectionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CardsCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CardsCacheTable,
          CardsCacheData,
          $$CardsCacheTableFilterComposer,
          $$CardsCacheTableOrderingComposer,
          $$CardsCacheTableAnnotationComposer,
          $$CardsCacheTableCreateCompanionBuilder,
          $$CardsCacheTableUpdateCompanionBuilder,
          (CardsCacheData, $$CardsCacheTableReferences),
          CardsCacheData,
          PrefetchHooks Function({bool collectionItemsRefs})
        > {
  $$CardsCacheTableTableManager(_$AppDatabase db, $CardsCacheTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CardsCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CardsCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CardsCacheTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> fetchedAt = const Value.absent(),
                Value<String?> previousJson = const Value.absent(),
                Value<int?> previousFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCacheCompanion(
                id: id,
                json: json,
                fetchedAt: fetchedAt,
                previousJson: previousJson,
                previousFetchedAt: previousFetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String json,
                required int fetchedAt,
                Value<String?> previousJson = const Value.absent(),
                Value<int?> previousFetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CardsCacheCompanion.insert(
                id: id,
                json: json,
                fetchedAt: fetchedAt,
                previousJson: previousJson,
                previousFetchedAt: previousFetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CardsCacheTable, CardsCacheData>(table),
                  $$CardsCacheTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({collectionItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (collectionItemsRefs) db.collectionItems,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (collectionItemsRefs)
                    await $_getPrefetchedData<
                      CardsCacheData,
                      $CardsCacheTable,
                      CollectionItem
                    >(
                      currentTable: table,
                      referencedTable: $$CardsCacheTableReferences
                          ._collectionItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CardsCacheTableReferences(
                            db,
                            table,
                            p0,
                          ).collectionItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.cardId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CardsCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CardsCacheTable,
      CardsCacheData,
      $$CardsCacheTableFilterComposer,
      $$CardsCacheTableOrderingComposer,
      $$CardsCacheTableAnnotationComposer,
      $$CardsCacheTableCreateCompanionBuilder,
      $$CardsCacheTableUpdateCompanionBuilder,
      (CardsCacheData, $$CardsCacheTableReferences),
      CardsCacheData,
      PrefetchHooks Function({bool collectionItemsRefs})
    >;
typedef $$CollectionItemsTableCreateCompanionBuilder =
    CollectionItemsCompanion Function({
      Value<int> id,
      required String cardId,
      required String variant,
      Value<int> quantity,
      Value<String> condition,
      Value<String> language,
      Value<String?> scanPath,
      Value<String?> notes,
      Value<int?> acquiredAt,
      Value<double?> pricePaid,
      required int addedAt,
    });
typedef $$CollectionItemsTableUpdateCompanionBuilder =
    CollectionItemsCompanion Function({
      Value<int> id,
      Value<String> cardId,
      Value<String> variant,
      Value<int> quantity,
      Value<String> condition,
      Value<String> language,
      Value<String?> scanPath,
      Value<String?> notes,
      Value<int?> acquiredAt,
      Value<double?> pricePaid,
      Value<int> addedAt,
    });

final class $$CollectionItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $CollectionItemsTable, CollectionItem> {
  $$CollectionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CardsCacheTable _cardIdTable(_$AppDatabase db) =>
      db.cardsCache.createAlias('collection_items__card_id__cards_cache__id');

  $$CardsCacheTableProcessedTableManager get cardId {
    final $_column = $_itemColumn<String>('card_id')!;

    final manager = $$CardsCacheTableTableManager(
      $_db,
      $_db.cardsCache,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_cardIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$CollectionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scanPath => $composableBuilder(
    column: $table.scanPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pricePaid => $composableBuilder(
    column: $table.pricePaid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CardsCacheTableFilterComposer get cardId {
    final $$CardsCacheTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cardsCache,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsCacheTableFilterComposer(
            $db: $db,
            $table: $db.cardsCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get variant => $composableBuilder(
    column: $table.variant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get condition => $composableBuilder(
    column: $table.condition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get language => $composableBuilder(
    column: $table.language,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scanPath => $composableBuilder(
    column: $table.scanPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pricePaid => $composableBuilder(
    column: $table.pricePaid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CardsCacheTableOrderingComposer get cardId {
    final $$CardsCacheTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cardsCache,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsCacheTableOrderingComposer(
            $db: $db,
            $table: $db.cardsCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CollectionItemsTable> {
  $$CollectionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get variant =>
      $composableBuilder(column: $table.variant, builder: (column) => column);

  GeneratedColumn<int> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get condition =>
      $composableBuilder(column: $table.condition, builder: (column) => column);

  GeneratedColumn<String> get language =>
      $composableBuilder(column: $table.language, builder: (column) => column);

  GeneratedColumn<String> get scanPath =>
      $composableBuilder(column: $table.scanPath, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<int> get acquiredAt => $composableBuilder(
    column: $table.acquiredAt,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pricePaid =>
      $composableBuilder(column: $table.pricePaid, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  $$CardsCacheTableAnnotationComposer get cardId {
    final $$CardsCacheTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.cardId,
      referencedTable: $db.cardsCache,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CardsCacheTableAnnotationComposer(
            $db: $db,
            $table: $db.cardsCache,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$CollectionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CollectionItemsTable,
          CollectionItem,
          $$CollectionItemsTableFilterComposer,
          $$CollectionItemsTableOrderingComposer,
          $$CollectionItemsTableAnnotationComposer,
          $$CollectionItemsTableCreateCompanionBuilder,
          $$CollectionItemsTableUpdateCompanionBuilder,
          (CollectionItem, $$CollectionItemsTableReferences),
          CollectionItem,
          PrefetchHooks Function({bool cardId})
        > {
  $$CollectionItemsTableTableManager(
    _$AppDatabase db,
    $CollectionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CollectionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CollectionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CollectionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> cardId = const Value.absent(),
                Value<String> variant = const Value.absent(),
                Value<int> quantity = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> scanPath = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> acquiredAt = const Value.absent(),
                Value<double?> pricePaid = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
              }) => CollectionItemsCompanion(
                id: id,
                cardId: cardId,
                variant: variant,
                quantity: quantity,
                condition: condition,
                language: language,
                scanPath: scanPath,
                notes: notes,
                acquiredAt: acquiredAt,
                pricePaid: pricePaid,
                addedAt: addedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String cardId,
                required String variant,
                Value<int> quantity = const Value.absent(),
                Value<String> condition = const Value.absent(),
                Value<String> language = const Value.absent(),
                Value<String?> scanPath = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<int?> acquiredAt = const Value.absent(),
                Value<double?> pricePaid = const Value.absent(),
                required int addedAt,
              }) => CollectionItemsCompanion.insert(
                id: id,
                cardId: cardId,
                variant: variant,
                quantity: quantity,
                condition: condition,
                language: language,
                scanPath: scanPath,
                notes: notes,
                acquiredAt: acquiredAt,
                pricePaid: pricePaid,
                addedAt: addedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CollectionItemsTable, CollectionItem>(table),
                  $$CollectionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({cardId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (cardId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.cardId,
                        referencedTable: $$CollectionItemsTableReferences
                            ._cardIdTable(db),
                        referencedColumn: $$CollectionItemsTableReferences
                            ._cardIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$CollectionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CollectionItemsTable,
      CollectionItem,
      $$CollectionItemsTableFilterComposer,
      $$CollectionItemsTableOrderingComposer,
      $$CollectionItemsTableAnnotationComposer,
      $$CollectionItemsTableCreateCompanionBuilder,
      $$CollectionItemsTableUpdateCompanionBuilder,
      (CollectionItem, $$CollectionItemsTableReferences),
      CollectionItem,
      PrefetchHooks Function({bool cardId})
    >;
typedef $$SetListsTableCreateCompanionBuilder = SetListsCompanion Function({
  required String lang,
  required String json,
  required int checkedAt,
  Value<int> rowid,
});
typedef $$SetListsTableUpdateCompanionBuilder = SetListsCompanion Function({
  Value<String> lang,
  Value<String> json,
  Value<int> checkedAt,
  Value<int> rowid,
});

class $$SetListsTableFilterComposer
    extends Composer<_$AppDatabase, $SetListsTable> {
  $$SetListsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SetListsTableOrderingComposer
    extends Composer<_$AppDatabase, $SetListsTable> {
  $$SetListsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get lang => $composableBuilder(
    column: $table.lang,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get checkedAt => $composableBuilder(
    column: $table.checkedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SetListsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SetListsTable> {
  $$SetListsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<int> get checkedAt =>
      $composableBuilder(column: $table.checkedAt, builder: (column) => column);
}

class $$SetListsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SetListsTable,
          SetList,
          $$SetListsTableFilterComposer,
          $$SetListsTableOrderingComposer,
          $$SetListsTableAnnotationComposer,
          $$SetListsTableCreateCompanionBuilder,
          $$SetListsTableUpdateCompanionBuilder,
          (SetList, BaseReferences<_$AppDatabase, $SetListsTable, SetList>),
          SetList,
          PrefetchHooks Function()
        > {
  $$SetListsTableTableManager(_$AppDatabase db, $SetListsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SetListsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SetListsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SetListsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> lang = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> checkedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SetListsCompanion(
                lang: lang,
                json: json,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String lang,
                required String json,
                required int checkedAt,
                Value<int> rowid = const Value.absent(),
              }) => SetListsCompanion.insert(
                lang: lang,
                json: json,
                checkedAt: checkedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SetListsTable, SetList>(table),
                  BaseReferences<_$AppDatabase, $SetListsTable, SetList>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SetListsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SetListsTable,
      SetList,
      $$SetListsTableFilterComposer,
      $$SetListsTableOrderingComposer,
      $$SetListsTableAnnotationComposer,
      $$SetListsTableCreateCompanionBuilder,
      $$SetListsTableUpdateCompanionBuilder,
      (SetList, BaseReferences<_$AppDatabase, $SetListsTable, SetList>),
      SetList,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$CardsCacheTableTableManager get cardsCache =>
      $$CardsCacheTableTableManager(_db, _db.cardsCache);
  $$CollectionItemsTableTableManager get collectionItems =>
      $$CollectionItemsTableTableManager(_db, _db.collectionItems);
  $$SetListsTableTableManager get setLists =>
      $$SetListsTableTableManager(_db, _db.setLists);
}
