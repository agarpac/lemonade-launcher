// ignore_for_file: type=lint
part of 'database.dart';

class $AppsTable extends Apps with TableInfo<$AppsTable, App> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _packageNameMeta =
      const VerificationMeta('packageName');
  @override
  late final GeneratedColumn<String> packageName = GeneratedColumn<String>(
      'package_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
      'hidden', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("hidden" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastLaunchedAtMeta =
      const VerificationMeta('lastLaunchedAt');
  @override
  late final GeneratedColumn<DateTime> lastLaunchedAt =
      GeneratedColumn<DateTime>('last_launched_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [packageName, name, version, hidden, lastLaunchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'apps';
  @override
  VerificationContext validateIntegrity(Insertable<App> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('package_name')) {
      context.handle(
          _packageNameMeta,
          packageName.isAcceptableOrUnknown(
              data['package_name']!, _packageNameMeta));
    } else if (isInserting) {
      context.missing(_packageNameMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta,
          hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('last_launched_at')) {
      context.handle(
          _lastLaunchedAtMeta,
          lastLaunchedAt.isAcceptableOrUnknown(
              data['last_launched_at']!, _lastLaunchedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {packageName};
  @override
  App map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return App(
      packageName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}package_name'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      hidden: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}hidden'])!,
      lastLaunchedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_launched_at']),
    );
  }

  @override
  $AppsTable createAlias(String alias) {
    return $AppsTable(attachedDatabase, alias);
  }
}

class AppsCompanion extends UpdateCompanion<App> {
  final Value<String> packageName;
  final Value<String> name;
  final Value<String> version;
  final Value<bool> hidden;
  final Value<DateTime?> lastLaunchedAt;
  final Value<int> rowid;
  const AppsCompanion({
    this.packageName = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.hidden = const Value.absent(),
    this.lastLaunchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppsCompanion.insert({
    required String packageName,
    required String name,
    required String version,
    this.hidden = const Value.absent(),
    this.lastLaunchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : packageName = Value(packageName),
        name = Value(name),
        version = Value(version);
  static Insertable<App> custom({
    Expression<String>? packageName,
    Expression<String>? name,
    Expression<String>? version,
    Expression<bool>? hidden,
    Expression<DateTime>? lastLaunchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (packageName != null) 'package_name': packageName,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (hidden != null) 'hidden': hidden,
      if (lastLaunchedAt != null) 'last_launched_at': lastLaunchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppsCompanion copyWith(
      {Value<String>? packageName,
      Value<String>? name,
      Value<String>? version,
      Value<bool>? hidden,
      Value<DateTime?>? lastLaunchedAt,
      Value<int>? rowid}) {
    return AppsCompanion(
      packageName: packageName ?? this.packageName,
      name: name ?? this.name,
      version: version ?? this.version,
      hidden: hidden ?? this.hidden,
      lastLaunchedAt: lastLaunchedAt ?? this.lastLaunchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (packageName.present) {
      map['package_name'] = Variable<String>(packageName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (lastLaunchedAt.present) {
      map['last_launched_at'] = Variable<DateTime>(lastLaunchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppsCompanion(')
          ..write('packageName: $packageName, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('hidden: $hidden, ')
          ..write('lastLaunchedAt: $lastLaunchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sortMeta = const VerificationMeta('sort');
  @override
  late final GeneratedColumnWithTypeConverter<CategorySort, int> sort =
      GeneratedColumn<int>('sort', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: Constant(Category.Sort.index))
          .withConverter<CategorySort>($CategoriesTable.$convertersort);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumnWithTypeConverter<CategoryType, int> type =
      GeneratedColumn<int>('type', aliasedName, false,
              type: DriftSqlType.int,
              requiredDuringInsert: false,
              defaultValue: Constant(Category.Type.index))
          .withConverter<CategoryType>($CategoriesTable.$convertertype);
  static const VerificationMeta _rowHeightMeta =
      const VerificationMeta('rowHeight');
  @override
  late final GeneratedColumn<int> rowHeight = GeneratedColumn<int>(
      'row_height', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(Category.RowHeight));
  static const VerificationMeta _columnsCountMeta =
      const VerificationMeta('columnsCount');
  @override
  late final GeneratedColumn<int> columnsCount = GeneratedColumn<int>(
      'columns_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(Category.ColumnsCount));
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, sort, type, rowHeight, columnsCount, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    context.handle(_sortMeta, const VerificationResult.success());
    context.handle(_typeMeta, const VerificationResult.success());
    if (data.containsKey('row_height')) {
      context.handle(_rowHeightMeta,
          rowHeight.isAcceptableOrUnknown(data['row_height']!, _rowHeightMeta));
    }
    if (data.containsKey('columns_count')) {
      context.handle(
          _columnsCountMeta,
          columnsCount.isAcceptableOrUnknown(
              data['columns_count']!, _columnsCountMeta));
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
      columnsCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}columns_count'])!,
      rowHeight: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}row_height'])!,
      sort: $CategoriesTable.$convertersort.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort'])!),
      type: $CategoriesTable.$convertertype.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}type'])!),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategorySort, int, int> $convertersort =
      const EnumIndexConverter<CategorySort>(CategorySort.values);
  static JsonTypeConverter2<CategoryType, int, int> $convertertype =
      const EnumIndexConverter<CategoryType>(CategoryType.values);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String> name;
  final Value<CategorySort> sort;
  final Value<CategoryType> type;
  final Value<int> rowHeight;
  final Value<int> columnsCount;
  final Value<int> order;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sort = const Value.absent(),
    this.type = const Value.absent(),
    this.rowHeight = const Value.absent(),
    this.columnsCount = const Value.absent(),
    this.order = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.sort = const Value.absent(),
    this.type = const Value.absent(),
    this.rowHeight = const Value.absent(),
    this.columnsCount = const Value.absent(),
    required int order,
  })  : name = Value(name),
        order = Value(order);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<int>? sort,
    Expression<int>? type,
    Expression<int>? rowHeight,
    Expression<int>? columnsCount,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sort != null) 'sort': sort,
      if (type != null) 'type': type,
      if (rowHeight != null) 'row_height': rowHeight,
      if (columnsCount != null) 'columns_count': columnsCount,
      if (order != null) 'order': order,
    });
  }

  CategoriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<CategorySort>? sort,
      Value<CategoryType>? type,
      Value<int>? rowHeight,
      Value<int>? columnsCount,
      Value<int>? order}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sort: sort ?? this.sort,
      type: type ?? this.type,
      rowHeight: rowHeight ?? this.rowHeight,
      columnsCount: columnsCount ?? this.columnsCount,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sort.present) {
      map['sort'] =
          Variable<int>($CategoriesTable.$convertersort.toSql(sort.value));
    }
    if (type.present) {
      map['type'] =
          Variable<int>($CategoriesTable.$convertertype.toSql(type.value));
    }
    if (rowHeight.present) {
      map['row_height'] = Variable<int>(rowHeight.value);
    }
    if (columnsCount.present) {
      map['columns_count'] = Variable<int>(columnsCount.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sort: $sort, ')
          ..write('type: $type, ')
          ..write('rowHeight: $rowHeight, ')
          ..write('columnsCount: $columnsCount, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

class $AppsCategoriesTable extends AppsCategories
    with TableInfo<$AppsCategoriesTable, AppCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppsCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      $customConstraints: 'REFERENCES categories(id) ON DELETE CASCADE');
  static const VerificationMeta _appPackageNameMeta =
      const VerificationMeta('appPackageName');
  @override
  late final GeneratedColumn<String> appPackageName = GeneratedColumn<String>(
      'app_package_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      $customConstraints: 'REFERENCES apps(package_name) ON DELETE CASCADE');
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [categoryId, appPackageName, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'apps_categories';
  @override
  VerificationContext validateIntegrity(Insertable<AppCategory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('app_package_name')) {
      context.handle(
          _appPackageNameMeta,
          appPackageName.isAcceptableOrUnknown(
              data['app_package_name']!, _appPackageNameMeta));
    } else if (isInserting) {
      context.missing(_appPackageNameMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {categoryId, appPackageName};
  @override
  AppCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppCategory(
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id'])!,
      appPackageName: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}app_package_name'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
    );
  }

  @override
  $AppsCategoriesTable createAlias(String alias) {
    return $AppsCategoriesTable(attachedDatabase, alias);
  }
}

class AppCategory extends DataClass implements Insertable<AppCategory> {
  final int categoryId;
  final String appPackageName;
  final int order;
  const AppCategory(
      {required this.categoryId,
      required this.appPackageName,
      required this.order});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category_id'] = Variable<int>(categoryId);
    map['app_package_name'] = Variable<String>(appPackageName);
    map['order'] = Variable<int>(order);
    return map;
  }

  AppsCategoriesCompanion toCompanion(bool nullToAbsent) {
    return AppsCategoriesCompanion(
      categoryId: Value(categoryId),
      appPackageName: Value(appPackageName),
      order: Value(order),
    );
  }

  factory AppCategory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppCategory(
      categoryId: serializer.fromJson<int>(json['categoryId']),
      appPackageName: serializer.fromJson<String>(json['appPackageName']),
      order: serializer.fromJson<int>(json['order']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'categoryId': serializer.toJson<int>(categoryId),
      'appPackageName': serializer.toJson<String>(appPackageName),
      'order': serializer.toJson<int>(order),
    };
  }

  AppCategory copyWith({int? categoryId, String? appPackageName, int? order}) =>
      AppCategory(
        categoryId: categoryId ?? this.categoryId,
        appPackageName: appPackageName ?? this.appPackageName,
        order: order ?? this.order,
      );
  AppCategory copyWithCompanion(AppsCategoriesCompanion data) {
    return AppCategory(
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      appPackageName: data.appPackageName.present
          ? data.appPackageName.value
          : this.appPackageName,
      order: data.order.present ? data.order.value : this.order,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppCategory(')
          ..write('categoryId: $categoryId, ')
          ..write('appPackageName: $appPackageName, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(categoryId, appPackageName, order);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppCategory &&
          other.categoryId == this.categoryId &&
          other.appPackageName == this.appPackageName &&
          other.order == this.order);
}

class AppsCategoriesCompanion extends UpdateCompanion<AppCategory> {
  final Value<int> categoryId;
  final Value<String> appPackageName;
  final Value<int> order;
  final Value<int> rowid;
  const AppsCategoriesCompanion({
    this.categoryId = const Value.absent(),
    this.appPackageName = const Value.absent(),
    this.order = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppsCategoriesCompanion.insert({
    required int categoryId,
    required String appPackageName,
    required int order,
    this.rowid = const Value.absent(),
  })  : categoryId = Value(categoryId),
        appPackageName = Value(appPackageName),
        order = Value(order);
  static Insertable<AppCategory> custom({
    Expression<int>? categoryId,
    Expression<String>? appPackageName,
    Expression<int>? order,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (categoryId != null) 'category_id': categoryId,
      if (appPackageName != null) 'app_package_name': appPackageName,
      if (order != null) 'order': order,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppsCategoriesCompanion copyWith(
      {Value<int>? categoryId,
      Value<String>? appPackageName,
      Value<int>? order,
      Value<int>? rowid}) {
    return AppsCategoriesCompanion(
      categoryId: categoryId ?? this.categoryId,
      appPackageName: appPackageName ?? this.appPackageName,
      order: order ?? this.order,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (appPackageName.present) {
      map['app_package_name'] = Variable<String>(appPackageName.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppsCategoriesCompanion(')
          ..write('categoryId: $categoryId, ')
          ..write('appPackageName: $appPackageName, ')
          ..write('order: $order, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LauncherSpacersTable extends LauncherSpacers
    with TableInfo<$LauncherSpacersTable, LauncherSpacer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LauncherSpacersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<int> height = GeneratedColumn<int>(
      'height', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, height, order];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'launcher_spacers';
  @override
  VerificationContext validateIntegrity(Insertable<LauncherSpacer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('height')) {
      context.handle(_heightMeta,
          height.isAcceptableOrUnknown(data['height']!, _heightMeta));
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LauncherSpacer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LauncherSpacer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
      height: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}height'])!,
    );
  }

  @override
  $LauncherSpacersTable createAlias(String alias) {
    return $LauncherSpacersTable(attachedDatabase, alias);
  }
}

class LauncherSpacersCompanion extends UpdateCompanion<LauncherSpacer> {
  final Value<int> id;
  final Value<int> height;
  final Value<int> order;
  const LauncherSpacersCompanion({
    this.id = const Value.absent(),
    this.height = const Value.absent(),
    this.order = const Value.absent(),
  });
  LauncherSpacersCompanion.insert({
    this.id = const Value.absent(),
    required int height,
    required int order,
  })  : height = Value(height),
        order = Value(order);
  static Insertable<LauncherSpacer> custom({
    Expression<int>? id,
    Expression<int>? height,
    Expression<int>? order,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (height != null) 'height': height,
      if (order != null) 'order': order,
    });
  }

  LauncherSpacersCompanion copyWith(
      {Value<int>? id, Value<int>? height, Value<int>? order}) {
    return LauncherSpacersCompanion(
      id: id ?? this.id,
      height: height ?? this.height,
      order: order ?? this.order,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (height.present) {
      map['height'] = Variable<int>(height.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LauncherSpacersCompanion(')
          ..write('id: $id, ')
          ..write('height: $height, ')
          ..write('order: $order')
          ..write(')'))
        .toString();
  }
}

class $ContentShortcutsTable extends ContentShortcuts
    with TableInfo<$ContentShortcutsTable, ContentShortcutRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentShortcutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _sectionIdMeta =
      const VerificationMeta('sectionId');
  @override
  late final GeneratedColumn<int> sectionId = GeneratedColumn<int>(
      'section_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sectionOrderMeta =
      const VerificationMeta('sectionOrder');
  @override
  late final GeneratedColumn<int> sectionOrder = GeneratedColumn<int>(
      'section_order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _orderMeta = const VerificationMeta('order');
  @override
  late final GeneratedColumn<int> order = GeneratedColumn<int>(
      'order', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
      'uri', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetPackageMeta =
      const VerificationMeta('targetPackage');
  @override
  late final GeneratedColumn<String> targetPackage = GeneratedColumn<String>(
      'target_package', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, sectionId, sectionOrder, order, label, uri, targetPackage];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_shortcuts';
  @override
  VerificationContext validateIntegrity(Insertable<ContentShortcutRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('section_id')) {
      context.handle(_sectionIdMeta,
          sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta));
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('section_order')) {
      context.handle(
          _sectionOrderMeta,
          sectionOrder.isAcceptableOrUnknown(
              data['section_order']!, _sectionOrderMeta));
    } else if (isInserting) {
      context.missing(_sectionOrderMeta);
    }
    if (data.containsKey('order')) {
      context.handle(
          _orderMeta, order.isAcceptableOrUnknown(data['order']!, _orderMeta));
    } else if (isInserting) {
      context.missing(_orderMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(
          _uriMeta, uri.isAcceptableOrUnknown(data['uri']!, _uriMeta));
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('target_package')) {
      context.handle(
          _targetPackageMeta,
          targetPackage.isAcceptableOrUnknown(
              data['target_package']!, _targetPackageMeta));
    } else if (isInserting) {
      context.missing(_targetPackageMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentShortcutRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentShortcutRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      sectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}section_id'])!,
      sectionOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}section_order'])!,
      order: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}order'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      uri: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}uri'])!,
      targetPackage: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_package'])!,
    );
  }

  @override
  $ContentShortcutsTable createAlias(String alias) {
    return $ContentShortcutsTable(attachedDatabase, alias);
  }
}

class ContentShortcutRow extends DataClass
    implements Insertable<ContentShortcutRow> {
  final int id;

  /// Groups shortcuts into one launcher section.
  final int sectionId;

  /// The order that places the whole section among the launcher's sections.
  /// Held by every row of the section and always written for the whole group at
  /// once, by `FLauncherDatabase.updateContentShortcutSectionOrder`.
  final int sectionOrder;

  /// Position of this shortcut inside its section.
  final int order;
  final String label;
  final String uri;
  final String targetPackage;
  const ContentShortcutRow(
      {required this.id,
      required this.sectionId,
      required this.sectionOrder,
      required this.order,
      required this.label,
      required this.uri,
      required this.targetPackage});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['section_id'] = Variable<int>(sectionId);
    map['section_order'] = Variable<int>(sectionOrder);
    map['order'] = Variable<int>(order);
    map['label'] = Variable<String>(label);
    map['uri'] = Variable<String>(uri);
    map['target_package'] = Variable<String>(targetPackage);
    return map;
  }

  ContentShortcutsCompanion toCompanion(bool nullToAbsent) {
    return ContentShortcutsCompanion(
      id: Value(id),
      sectionId: Value(sectionId),
      sectionOrder: Value(sectionOrder),
      order: Value(order),
      label: Value(label),
      uri: Value(uri),
      targetPackage: Value(targetPackage),
    );
  }

  factory ContentShortcutRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentShortcutRow(
      id: serializer.fromJson<int>(json['id']),
      sectionId: serializer.fromJson<int>(json['sectionId']),
      sectionOrder: serializer.fromJson<int>(json['sectionOrder']),
      order: serializer.fromJson<int>(json['order']),
      label: serializer.fromJson<String>(json['label']),
      uri: serializer.fromJson<String>(json['uri']),
      targetPackage: serializer.fromJson<String>(json['targetPackage']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sectionId': serializer.toJson<int>(sectionId),
      'sectionOrder': serializer.toJson<int>(sectionOrder),
      'order': serializer.toJson<int>(order),
      'label': serializer.toJson<String>(label),
      'uri': serializer.toJson<String>(uri),
      'targetPackage': serializer.toJson<String>(targetPackage),
    };
  }

  ContentShortcutRow copyWith(
          {int? id,
          int? sectionId,
          int? sectionOrder,
          int? order,
          String? label,
          String? uri,
          String? targetPackage}) =>
      ContentShortcutRow(
        id: id ?? this.id,
        sectionId: sectionId ?? this.sectionId,
        sectionOrder: sectionOrder ?? this.sectionOrder,
        order: order ?? this.order,
        label: label ?? this.label,
        uri: uri ?? this.uri,
        targetPackage: targetPackage ?? this.targetPackage,
      );
  ContentShortcutRow copyWithCompanion(ContentShortcutsCompanion data) {
    return ContentShortcutRow(
      id: data.id.present ? data.id.value : this.id,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      sectionOrder: data.sectionOrder.present
          ? data.sectionOrder.value
          : this.sectionOrder,
      order: data.order.present ? data.order.value : this.order,
      label: data.label.present ? data.label.value : this.label,
      uri: data.uri.present ? data.uri.value : this.uri,
      targetPackage: data.targetPackage.present
          ? data.targetPackage.value
          : this.targetPackage,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentShortcutRow(')
          ..write('id: $id, ')
          ..write('sectionId: $sectionId, ')
          ..write('sectionOrder: $sectionOrder, ')
          ..write('order: $order, ')
          ..write('label: $label, ')
          ..write('uri: $uri, ')
          ..write('targetPackage: $targetPackage')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, sectionId, sectionOrder, order, label, uri, targetPackage);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentShortcutRow &&
          other.id == this.id &&
          other.sectionId == this.sectionId &&
          other.sectionOrder == this.sectionOrder &&
          other.order == this.order &&
          other.label == this.label &&
          other.uri == this.uri &&
          other.targetPackage == this.targetPackage);
}

class ContentShortcutsCompanion extends UpdateCompanion<ContentShortcutRow> {
  final Value<int> id;
  final Value<int> sectionId;
  final Value<int> sectionOrder;
  final Value<int> order;
  final Value<String> label;
  final Value<String> uri;
  final Value<String> targetPackage;
  const ContentShortcutsCompanion({
    this.id = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.sectionOrder = const Value.absent(),
    this.order = const Value.absent(),
    this.label = const Value.absent(),
    this.uri = const Value.absent(),
    this.targetPackage = const Value.absent(),
  });
  ContentShortcutsCompanion.insert({
    this.id = const Value.absent(),
    required int sectionId,
    required int sectionOrder,
    required int order,
    required String label,
    required String uri,
    required String targetPackage,
  })  : sectionId = Value(sectionId),
        sectionOrder = Value(sectionOrder),
        order = Value(order),
        label = Value(label),
        uri = Value(uri),
        targetPackage = Value(targetPackage);
  static Insertable<ContentShortcutRow> custom({
    Expression<int>? id,
    Expression<int>? sectionId,
    Expression<int>? sectionOrder,
    Expression<int>? order,
    Expression<String>? label,
    Expression<String>? uri,
    Expression<String>? targetPackage,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sectionId != null) 'section_id': sectionId,
      if (sectionOrder != null) 'section_order': sectionOrder,
      if (order != null) 'order': order,
      if (label != null) 'label': label,
      if (uri != null) 'uri': uri,
      if (targetPackage != null) 'target_package': targetPackage,
    });
  }

  ContentShortcutsCompanion copyWith(
      {Value<int>? id,
      Value<int>? sectionId,
      Value<int>? sectionOrder,
      Value<int>? order,
      Value<String>? label,
      Value<String>? uri,
      Value<String>? targetPackage}) {
    return ContentShortcutsCompanion(
      id: id ?? this.id,
      sectionId: sectionId ?? this.sectionId,
      sectionOrder: sectionOrder ?? this.sectionOrder,
      order: order ?? this.order,
      label: label ?? this.label,
      uri: uri ?? this.uri,
      targetPackage: targetPackage ?? this.targetPackage,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<int>(sectionId.value);
    }
    if (sectionOrder.present) {
      map['section_order'] = Variable<int>(sectionOrder.value);
    }
    if (order.present) {
      map['order'] = Variable<int>(order.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (targetPackage.present) {
      map['target_package'] = Variable<String>(targetPackage.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentShortcutsCompanion(')
          ..write('id: $id, ')
          ..write('sectionId: $sectionId, ')
          ..write('sectionOrder: $sectionOrder, ')
          ..write('order: $order, ')
          ..write('label: $label, ')
          ..write('uri: $uri, ')
          ..write('targetPackage: $targetPackage')
          ..write(')'))
        .toString();
  }
}

abstract class _$FLauncherDatabase extends GeneratedDatabase {
  _$FLauncherDatabase(QueryExecutor e) : super(e);
  $FLauncherDatabaseManager get managers => $FLauncherDatabaseManager(this);
  late final $AppsTable apps = $AppsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $AppsCategoriesTable appsCategories = $AppsCategoriesTable(this);
  late final $LauncherSpacersTable launcherSpacers =
      $LauncherSpacersTable(this);
  late final $ContentShortcutsTable contentShortcuts =
      $ContentShortcutsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [apps, categories, appsCategories, launcherSpacers, contentShortcuts];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('categories',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('apps_categories', kind: UpdateKind.delete),
            ],
          ),
          WritePropagation(
            on: TableUpdateQuery.onTableName('apps',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('apps_categories', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$AppsTableCreateCompanionBuilder = AppsCompanion Function({
  required String packageName,
  required String name,
  required String version,
  Value<bool> hidden,
  Value<DateTime?> lastLaunchedAt,
  Value<int> rowid,
});
typedef $$AppsTableUpdateCompanionBuilder = AppsCompanion Function({
  Value<String> packageName,
  Value<String> name,
  Value<String> version,
  Value<bool> hidden,
  Value<DateTime?> lastLaunchedAt,
  Value<int> rowid,
});

class $$AppsTableTableManager extends RootTableManager<
    _$FLauncherDatabase,
    $AppsTable,
    App,
    $$AppsTableFilterComposer,
    $$AppsTableOrderingComposer,
    $$AppsTableCreateCompanionBuilder,
    $$AppsTableUpdateCompanionBuilder> {
  $$AppsTableTableManager(_$FLauncherDatabase db, $AppsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AppsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AppsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> packageName = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<bool> hidden = const Value.absent(),
            Value<DateTime?> lastLaunchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppsCompanion(
            packageName: packageName,
            name: name,
            version: version,
            hidden: hidden,
            lastLaunchedAt: lastLaunchedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String packageName,
            required String name,
            required String version,
            Value<bool> hidden = const Value.absent(),
            Value<DateTime?> lastLaunchedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppsCompanion.insert(
            packageName: packageName,
            name: name,
            version: version,
            hidden: hidden,
            lastLaunchedAt: lastLaunchedAt,
            rowid: rowid,
          ),
        ));
}

class $$AppsTableFilterComposer
    extends FilterComposer<_$FLauncherDatabase, $AppsTable> {
  $$AppsTableFilterComposer(super.$state);
  ColumnFilters<String> get packageName => $state.composableBuilder(
      column: $state.table.packageName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get version => $state.composableBuilder(
      column: $state.table.version,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get hidden => $state.composableBuilder(
      column: $state.table.hidden,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastLaunchedAt => $state.composableBuilder(
      column: $state.table.lastLaunchedAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter appsCategoriesRefs(
      ComposableFilter Function($$AppsCategoriesTableFilterComposer f) f) {
    final $$AppsCategoriesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.packageName,
        referencedTable: $state.db.appsCategories,
        getReferencedColumn: (t) => t.appPackageName,
        builder: (joinBuilder, parentComposers) =>
            $$AppsCategoriesTableFilterComposer(ComposerState($state.db,
                $state.db.appsCategories, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$AppsTableOrderingComposer
    extends OrderingComposer<_$FLauncherDatabase, $AppsTable> {
  $$AppsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get packageName => $state.composableBuilder(
      column: $state.table.packageName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get version => $state.composableBuilder(
      column: $state.table.version,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get hidden => $state.composableBuilder(
      column: $state.table.hidden,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastLaunchedAt => $state.composableBuilder(
      column: $state.table.lastLaunchedAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  required String name,
  Value<CategorySort> sort,
  Value<CategoryType> type,
  Value<int> rowHeight,
  Value<int> columnsCount,
  required int order,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<CategorySort> sort,
  Value<CategoryType> type,
  Value<int> rowHeight,
  Value<int> columnsCount,
  Value<int> order,
});

class $$CategoriesTableTableManager extends RootTableManager<
    _$FLauncherDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder> {
  $$CategoriesTableTableManager(_$FLauncherDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$CategoriesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$CategoriesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<CategorySort> sort = const Value.absent(),
            Value<CategoryType> type = const Value.absent(),
            Value<int> rowHeight = const Value.absent(),
            Value<int> columnsCount = const Value.absent(),
            Value<int> order = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            name: name,
            sort: sort,
            type: type,
            rowHeight: rowHeight,
            columnsCount: columnsCount,
            order: order,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<CategorySort> sort = const Value.absent(),
            Value<CategoryType> type = const Value.absent(),
            Value<int> rowHeight = const Value.absent(),
            Value<int> columnsCount = const Value.absent(),
            required int order,
          }) =>
              CategoriesCompanion.insert(
            id: id,
            name: name,
            sort: sort,
            type: type,
            rowHeight: rowHeight,
            columnsCount: columnsCount,
            order: order,
          ),
        ));
}

class $$CategoriesTableFilterComposer
    extends FilterComposer<_$FLauncherDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<CategorySort, CategorySort, int> get sort =>
      $state.composableBuilder(
          column: $state.table.sort,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnWithTypeConverterFilters<CategoryType, CategoryType, int> get type =>
      $state.composableBuilder(
          column: $state.table.type,
          builder: (column, joinBuilders) => ColumnWithTypeConverterFilters(
              column,
              joinBuilders: joinBuilders));

  ColumnFilters<int> get rowHeight => $state.composableBuilder(
      column: $state.table.rowHeight,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get columnsCount => $state.composableBuilder(
      column: $state.table.columnsCount,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ComposableFilter appsCategoriesRefs(
      ComposableFilter Function($$AppsCategoriesTableFilterComposer f) f) {
    final $$AppsCategoriesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $state.db.appsCategories,
        getReferencedColumn: (t) => t.categoryId,
        builder: (joinBuilder, parentComposers) =>
            $$AppsCategoriesTableFilterComposer(ComposerState($state.db,
                $state.db.appsCategories, joinBuilder, parentComposers)));
    return f(composer);
  }
}

class $$CategoriesTableOrderingComposer
    extends OrderingComposer<_$FLauncherDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sort => $state.composableBuilder(
      column: $state.table.sort,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get type => $state.composableBuilder(
      column: $state.table.type,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get rowHeight => $state.composableBuilder(
      column: $state.table.rowHeight,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get columnsCount => $state.composableBuilder(
      column: $state.table.columnsCount,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$AppsCategoriesTableCreateCompanionBuilder = AppsCategoriesCompanion
    Function({
  required int categoryId,
  required String appPackageName,
  required int order,
  Value<int> rowid,
});
typedef $$AppsCategoriesTableUpdateCompanionBuilder = AppsCategoriesCompanion
    Function({
  Value<int> categoryId,
  Value<String> appPackageName,
  Value<int> order,
  Value<int> rowid,
});

class $$AppsCategoriesTableTableManager extends RootTableManager<
    _$FLauncherDatabase,
    $AppsCategoriesTable,
    AppCategory,
    $$AppsCategoriesTableFilterComposer,
    $$AppsCategoriesTableOrderingComposer,
    $$AppsCategoriesTableCreateCompanionBuilder,
    $$AppsCategoriesTableUpdateCompanionBuilder> {
  $$AppsCategoriesTableTableManager(
      _$FLauncherDatabase db, $AppsCategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AppsCategoriesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AppsCategoriesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> categoryId = const Value.absent(),
            Value<String> appPackageName = const Value.absent(),
            Value<int> order = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppsCategoriesCompanion(
            categoryId: categoryId,
            appPackageName: appPackageName,
            order: order,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int categoryId,
            required String appPackageName,
            required int order,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppsCategoriesCompanion.insert(
            categoryId: categoryId,
            appPackageName: appPackageName,
            order: order,
            rowid: rowid,
          ),
        ));
}

class $$AppsCategoriesTableFilterComposer
    extends FilterComposer<_$FLauncherDatabase, $AppsCategoriesTable> {
  $$AppsCategoriesTableFilterComposer(super.$state);
  ColumnFilters<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  $$CategoriesTableFilterComposer get categoryId {
    final $$CategoriesTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $state.db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$CategoriesTableFilterComposer(ComposerState($state.db,
                $state.db.categories, joinBuilder, parentComposers)));
    return composer;
  }

  $$AppsTableFilterComposer get appPackageName {
    final $$AppsTableFilterComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.appPackageName,
        referencedTable: $state.db.apps,
        getReferencedColumn: (t) => t.packageName,
        builder: (joinBuilder, parentComposers) => $$AppsTableFilterComposer(
            ComposerState(
                $state.db, $state.db.apps, joinBuilder, parentComposers)));
    return composer;
  }
}

class $$AppsCategoriesTableOrderingComposer
    extends OrderingComposer<_$FLauncherDatabase, $AppsCategoriesTable> {
  $$AppsCategoriesTableOrderingComposer(super.$state);
  ColumnOrderings<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  $$CategoriesTableOrderingComposer get categoryId {
    final $$CategoriesTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.categoryId,
        referencedTable: $state.db.categories,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder, parentComposers) =>
            $$CategoriesTableOrderingComposer(ComposerState($state.db,
                $state.db.categories, joinBuilder, parentComposers)));
    return composer;
  }

  $$AppsTableOrderingComposer get appPackageName {
    final $$AppsTableOrderingComposer composer = $state.composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.appPackageName,
        referencedTable: $state.db.apps,
        getReferencedColumn: (t) => t.packageName,
        builder: (joinBuilder, parentComposers) => $$AppsTableOrderingComposer(
            ComposerState(
                $state.db, $state.db.apps, joinBuilder, parentComposers)));
    return composer;
  }
}

typedef $$LauncherSpacersTableCreateCompanionBuilder = LauncherSpacersCompanion
    Function({
  Value<int> id,
  required int height,
  required int order,
});
typedef $$LauncherSpacersTableUpdateCompanionBuilder = LauncherSpacersCompanion
    Function({
  Value<int> id,
  Value<int> height,
  Value<int> order,
});

class $$LauncherSpacersTableTableManager extends RootTableManager<
    _$FLauncherDatabase,
    $LauncherSpacersTable,
    LauncherSpacer,
    $$LauncherSpacersTableFilterComposer,
    $$LauncherSpacersTableOrderingComposer,
    $$LauncherSpacersTableCreateCompanionBuilder,
    $$LauncherSpacersTableUpdateCompanionBuilder> {
  $$LauncherSpacersTableTableManager(
      _$FLauncherDatabase db, $LauncherSpacersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$LauncherSpacersTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$LauncherSpacersTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> height = const Value.absent(),
            Value<int> order = const Value.absent(),
          }) =>
              LauncherSpacersCompanion(
            id: id,
            height: height,
            order: order,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int height,
            required int order,
          }) =>
              LauncherSpacersCompanion.insert(
            id: id,
            height: height,
            order: order,
          ),
        ));
}

class $$LauncherSpacersTableFilterComposer
    extends FilterComposer<_$FLauncherDatabase, $LauncherSpacersTable> {
  $$LauncherSpacersTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$LauncherSpacersTableOrderingComposer
    extends OrderingComposer<_$FLauncherDatabase, $LauncherSpacersTable> {
  $$LauncherSpacersTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get height => $state.composableBuilder(
      column: $state.table.height,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$ContentShortcutsTableCreateCompanionBuilder
    = ContentShortcutsCompanion Function({
  Value<int> id,
  required int sectionId,
  required int sectionOrder,
  required int order,
  required String label,
  required String uri,
  required String targetPackage,
});
typedef $$ContentShortcutsTableUpdateCompanionBuilder
    = ContentShortcutsCompanion Function({
  Value<int> id,
  Value<int> sectionId,
  Value<int> sectionOrder,
  Value<int> order,
  Value<String> label,
  Value<String> uri,
  Value<String> targetPackage,
});

class $$ContentShortcutsTableTableManager extends RootTableManager<
    _$FLauncherDatabase,
    $ContentShortcutsTable,
    ContentShortcutRow,
    $$ContentShortcutsTableFilterComposer,
    $$ContentShortcutsTableOrderingComposer,
    $$ContentShortcutsTableCreateCompanionBuilder,
    $$ContentShortcutsTableUpdateCompanionBuilder> {
  $$ContentShortcutsTableTableManager(
      _$FLauncherDatabase db, $ContentShortcutsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$ContentShortcutsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$ContentShortcutsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> sectionId = const Value.absent(),
            Value<int> sectionOrder = const Value.absent(),
            Value<int> order = const Value.absent(),
            Value<String> label = const Value.absent(),
            Value<String> uri = const Value.absent(),
            Value<String> targetPackage = const Value.absent(),
          }) =>
              ContentShortcutsCompanion(
            id: id,
            sectionId: sectionId,
            sectionOrder: sectionOrder,
            order: order,
            label: label,
            uri: uri,
            targetPackage: targetPackage,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int sectionId,
            required int sectionOrder,
            required int order,
            required String label,
            required String uri,
            required String targetPackage,
          }) =>
              ContentShortcutsCompanion.insert(
            id: id,
            sectionId: sectionId,
            sectionOrder: sectionOrder,
            order: order,
            label: label,
            uri: uri,
            targetPackage: targetPackage,
          ),
        ));
}

class $$ContentShortcutsTableFilterComposer
    extends FilterComposer<_$FLauncherDatabase, $ContentShortcutsTable> {
  $$ContentShortcutsTableFilterComposer(super.$state);
  ColumnFilters<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sectionId => $state.composableBuilder(
      column: $state.table.sectionId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get sectionOrder => $state.composableBuilder(
      column: $state.table.sectionOrder,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get label => $state.composableBuilder(
      column: $state.table.label,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get uri => $state.composableBuilder(
      column: $state.table.uri,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get targetPackage => $state.composableBuilder(
      column: $state.table.targetPackage,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$ContentShortcutsTableOrderingComposer
    extends OrderingComposer<_$FLauncherDatabase, $ContentShortcutsTable> {
  $$ContentShortcutsTableOrderingComposer(super.$state);
  ColumnOrderings<int> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sectionId => $state.composableBuilder(
      column: $state.table.sectionId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get sectionOrder => $state.composableBuilder(
      column: $state.table.sectionOrder,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get order => $state.composableBuilder(
      column: $state.table.order,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get label => $state.composableBuilder(
      column: $state.table.label,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get uri => $state.composableBuilder(
      column: $state.table.uri,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get targetPackage => $state.composableBuilder(
      column: $state.table.targetPackage,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $FLauncherDatabaseManager {
  final _$FLauncherDatabase _db;
  $FLauncherDatabaseManager(this._db);
  $$AppsTableTableManager get apps => $$AppsTableTableManager(_db, _db.apps);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$AppsCategoriesTableTableManager get appsCategories =>
      $$AppsCategoriesTableTableManager(_db, _db.appsCategories);
  $$LauncherSpacersTableTableManager get launcherSpacers =>
      $$LauncherSpacersTableTableManager(_db, _db.launcherSpacers);
  $$ContentShortcutsTableTableManager get contentShortcuts =>
      $$ContentShortcutsTableTableManager(_db, _db.contentShortcuts);
}
