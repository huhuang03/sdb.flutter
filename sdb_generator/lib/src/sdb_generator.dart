import 'dart:async';
import 'dart:mirrors';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/file_system/file_system.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' as cb;
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/source_gen.dart';
import 'package:sdb_annotation/sdb_annotation.dart';

class SdbGenerator extends Generator {
  static Type typeTable = reflectClass(TABLE).reflectedType;

  @override FutureOr<String> generate(LibraryReader library, BuildStep buildStep) {
    var inputId = buildStep.inputId;
    var file = _FileEx(library, inputId);
    if (!file.isApi()) {
      return null;
    }

    print("begin handle file: ${inputId.path}");
    return file.build(inputId);
  }
}

class _FileEx {
  static String PKG_SDB = "package:sdb/sdb.dart";
  List<_ClassElementEx> classes = [];
  List<String> pathSegments;
  bool hasInitialBuild = false;
  LibraryReader reader;

  _FileEx(this.reader, AssetId assetId) {
    this.classes = reader.classes.map((clz) => _ClassElementEx(clz, reader)).toList(growable: true);
    this.pathSegments = assetId.pathSegments;
  }

  bool isApi() {
    return "test" != this.pathSegments[0] && classes.any((c) => c.isApi());
  }

  void initialBuild() {
    if (hasInitialBuild) {
      return;
    }

    this.classes.forEach((c) => c.initial());
  }

  List<Directive> _buildDirectives() {
    List<Directive> rst = [];
    rst.addAll([Directive.import('dart:async')
      , Directive.import('dart:convert')
      , Directive.import(this.pathSegments.last)
      , Directive.import(PKG_SDB)]);


    return rst;
  }

  String build(AssetId inputId) {
    initialBuild();
    final library = Library((b) => b
    ..directives.addAll(_buildDirectives())
    ..body.addAll(this.classes.map((clz) => clz.build(inputId, b)).where((c) => c != null)));
    return DartFormatter().format('${library.accept(DartEmitter())}');
  }
}

class TableWrapper {
    DartObject table;

    TableWrapper(this.table);

    bool hasTable() {
      return table != null;
    }

    String name() {
      return table.getField("name").toStringValue();
    }

    String dbName() {
      return table.getField("dbName").toStringValue();
    }
}

class _ClassElementEx {
  static var CLASS_PREFIX = "Dao";
  static var BASE_DAO_CLASS_NAME = "SdbDao";
  ClassElement element;
  _FieldElementListEx fields;
  LibraryReader libraryReader;
  String name;
  TableWrapper table;

  _ClassElementEx(this.element, this.libraryReader) {
    this.name = "\$${element.name}${CLASS_PREFIX}";
    this.fields = _FieldElementListEx(this, this.element.fields);
    this.table = TableWrapper(TypeChecker.fromRuntime(SdbGenerator.typeTable).firstAnnotationOf(element, throwOnUnresolved: false));
  }

  bool isApi() {
    return this.table.hasTable();
  }

  void initial() {
    this.fields.initial();
  }

  Class build(AssetId inputId, cb.LibraryBuilder library) {
    if (!this.isApi()) return null;

    var c = Class((b) => b
    ..name = this.name
    ..fields.add(_buildTableField())
    ..constructors.add(this._buildConstructor())
    ..extend = refer("${BASE_DAO_CLASS_NAME}<${element.name}>")
    );
    return c;
  }

  cb.Field _buildTableField() {
    return cb.Field((b) => b
    ..static = true
    ..assignment = cb.literal(this.table.name()).code
    ..type = cb.refer("String")
    ..modifier = cb.FieldModifier.constant
    ..name = "TABLE_NAME");
  }

  Constructor _buildConstructor() {
    return Constructor((c) {c
      ..initializers.add(cb.refer('super').call([_buildTable(), _buildDGenerator()]).code);
    });
  }

  cb.Expression _buildTable() {
    Map<String, cb.Expression> namedParam = {};
    var dbName = this.table.dbName();
    if (dbName != null || dbName.isNotEmpty) {
      dbName = "default_db";
    }
    namedParam["dbName"] = cb.literal(dbName);

    return cb.refer("TABLE").call([cb.literal(this.table.name())], namedParam);
  }

  cb.Expression _buildDGenerator() {
    return cb.refer("DGenerator").call([], {
      "createSql": cb.refer("(v) {return \"${fields.buildSql()}\";}"),
      "dFromJson": cb.refer("(json) => ${element.name}.fromJson(json)"),
      "dToJson": cb.refer("(d) => d.toJson()")
    });
  }

}

class _FieldElementListEx {
  _ClassElementEx clazz;
  List<FieldElement> fields;

  _FieldElementListEx(this.clazz, this.fields);

  void initial() {

  }

  String buildSql() {
    var sqlFields = this.fields.map((field) {
      return "${field.name} ${mapToSqlType(field)}";
    }).toList().join(",");
    return "CREATE TABLE IF NOT EXISTS ${clazz.table.name()}(_id INT IDENTITY PRIMARY KEY, ${sqlFields})";
  }

  String mapToSqlType(FieldElement field) {
    var type = field.type;
    if (type.isDartCoreString) {
      return "TEXT";
    }

    if (type.isDartCoreInt) {
      return "int";
    }

    return "unknowType";
  }

}

//class _MethodElementEx {
//  static String VAR_API_METHOD = "apiMethod";
//  MethodElement element;
//  LibraryReader libraryReader;
//  _MethodParameters parameters;
//  String returnType;
//  Element returnTypeElement;
//
//  _MethodElementEx(this.libraryReader, this.element);
//
//  void initial() {
//    this.parameters = _MethodParameters(element.parameters);
//    var returnParameterizedType = this.element.returnType as ParameterizedType;
//    returnTypeElement = returnParameterizedType.typeArguments[0].element;
//    returnType = returnTypeElement.name;
//  }
//
//  Method build(AssetId inputId, cb.LibraryBuilder library) {
//    if (!isApi()) {
//      return null;
//    }
//    var returnType = element.returnType;
//    if (!returnType.isDartAsyncFuture) {
//      throw ArgumentError("for now can only support return Future");
//    }
//
//    this._buildReturnImport(inputId, library);
//
//    List<Code> codes = [];
//    codes.add(this._buildApiMethod());
//    codes.add(this._buildReturn());
//
//    var method = Method((b) => b
//    ..name = element.displayName
//    ..requiredParameters.addAll(parameters.buildRequiredParams())
//    ..optionalParameters.addAll(parameters.buildOptionParams())
//    ..annotations.add(refer("override"))
//    ..returns = refer(element.returnType.displayName, 'dart:async')
//    ..body = Block.of(codes.where((code) => code != null).toList())
//    );
//    return method;
//  }
//
//  // ugly
//  void _buildReturnImport(AssetId inputId, cb.LibraryBuilder library) {
//    var package = inputId.package;
//    var fullPath = returnTypeElement.library.source.toString();
//    if (!fullPath.startsWith("dart:")) {
//      // print("import: ${fullPath}");
//      // print("to import: ${this.libraryReader.pathToElement(returnTypeElemnt)}");
//      // fullPath = fullPath.substring(1);
//      // if (!fullPath.startsWith("${package}/")) {
//      //   throw ArgumentError("doesn't impl import out package: ${fullPath}, current pkg: ${inputId.path}");
//      // }
//      // fullPath = fullPath.replaceAll("/lib/", "/");
//      // fullPath = "package:" + fullPath;
//      library.directives.add(Directive.import(libraryReader.pathToElement(returnTypeElement).toString()));
//    }
//  }
//
//  Code _buildApiMethod() {
//    var params = <Expression>[];
//    final method = this._getHttpMethod();
//    params.add(literal(method[0]));
//    params.add(literal(method[1]));
//
//    return refer("ApiMethod").newInstance(params, parameters.buildNamedParams()).assignFinal(VAR_API_METHOD).statement;
//  }
//
//  Code _buildReturn() {
//    if (returnType == "String") {
//      return refer("apiMethod.send(thyi)").returned.statement;
//    } else {
//      return refer("apiMethod.send(thyi).then((d) => ${returnType}.fromJson(jsonDecode(d)))").returned.statement;
//    }
//  }
//
//  List<String> _getHttpMethod() {
//    var meta = element.metadata.first;
//    if (meta == null) {
//      return ["GET", ""];
//    }
//    print("httpMethod: ${meta}");
//    return [meta.constantValue.type.toString(), meta.constantValue.getField("path").toStringValue()];
//  }
//
//}
//
//class _MethodParameters {
//  List<ParameterElement> parameters;
//  /// key: the annotation value, value: the param name
//  Map<String, String> _headers;
//  Map<String, String> _fields;
//  Map<String, String> _quries;
//
//  _MethodParameters(this.parameters) {
//    this.parameters = this.parameters?? [];
////    this._headers = _extraAnnotaion<HEADER>((meta) => meta.constantValue.getField("key").toStringValue());
////    this._fields = _extraAnnotaion<FIELD>((meta) => meta.constantValue.getField("key").toStringValue());
////    this._quries = _extraAnnotaion<QUERY>((meta) => meta.constantValue.getField("key").toStringValue());
//  }
//
//  List<Parameter> buildOptionParams() {
//    List<Parameter> rst = [];
//    _buildParams(options: rst);
//    return rst;
//  }
//
//  List<Parameter> buildRequiredParams() {
//    List<Parameter> rst = [];
//    _buildParams(requires: rst);
//    return rst;
//  }
//
//  void _buildParams({List<Parameter> options, List<Parameter> requires}) {
//    print("parameters' size: ${parameters.length}");
//    parameters.forEach((pe) {
//      print("map pe: ${pe}");
//      var param = Parameter((b) {
//        b.name = pe.name;
//        b.type = refer(pe.type.name);
//        b.named = pe.isNamed;
//        if (pe.defaultValueCode != null) {
//          b.defaultTo = refer(pe.defaultValueCode).code;
//        }
//      });
//      if (pe.isOptional) {
//        print("options add ${param}");
//        options?.add(param);
//      } else {
//        print("requires add ${param}");
//        requires?.add(param);
//      }
//    });
//  }
//
//  Map<String, Expression> buildNamedParams() {
//    Map<String, Expression> namedArguments = {};
//    _buildNamedParams(namedArguments, "headers", _headers);
//    _buildNamedParams(namedArguments, "fields", _fields);
//    _buildNamedParams(namedArguments, "queries", _quries);
//    return namedArguments;
//  }
//
//  void _buildNamedParams<T>(Map<String, Expression> namedArguments, String name, Map<String, String> values) {
//    if (values != null && values.isNotEmpty) {
//      var genParam = values.entries.map((entry) => '"${entry.key}": ${entry.value}').join(",");
//      print(genParam);
//      namedArguments[name] = refer("{${genParam}}");
//    }
//  }
//
//  Map<String, String> _extraAnnotaion<T>(String valueBuilder(ElementAnnotation meta)) {
//    Map<String, String> rst = {};
//    parameters.forEach((param) {
//      if (param.metadata != null && param.metadata.isNotEmpty) {
//        var meta = param.metadata.first;
//        if (meta != null) {
//          var metaName = meta.element.toString();
//          if (metaName.startsWith("${T.toString()} ")) {
//              meta.computeConstantValue();
//              rst[valueBuilder(meta)] = param.name;
//          }
//        }
//      }
//    });
//    return rst;
//  }
//
//}
