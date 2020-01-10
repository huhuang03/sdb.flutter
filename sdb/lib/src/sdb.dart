import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sdb_annotation/sdb_annotation.dart';

class Sdb {
  static String defaultDbName = "";
}


typedef DSql<D> = String Function(int version);
typedef DToJson<D> = Map<String, dynamic> Function(D d);
typedef DFromJson<D> = D Function(Map<String, dynamic>);

class DGenerator<D> {
  DSql<D> createSql;
  DToJson<D> dToJson;
  DFromJson<D> dFromJson;

  /// this.createSql: 建表语句
  DGenerator({this.createSql, this.dToJson, this.dFromJson});

}

class SdbDao<D> {
  DGenerator<D> dGenerator;
  TABLE table;

  SdbDao(this.table, this.dGenerator) {
    assert(this.table.dbName != null && this.table.dbName.isNotEmpty);
  }

  Future<Database> get database async {
    var dbName = this.table.dbName;
    if (dbName == null || dbName.isEmpty) {
      dbName = Sdb.defaultDbName;
    }

    if (dbName == null || dbName.isEmpty) {
      dbName = "default_db";
    }

    return openDatabase(join(await getDatabasesPath(), "$dbName.db")
      , version: 1
      , onCreate: (db, v)  =>
            db.execute(dGenerator.createSql(v)))
    ;
  }


  Future<int> insert(D data) async {
    return database.then((db) {
      return db.insert(this.table.name, dGenerator.dToJson(data));
    });
  }

  Future<List<D>> findAll(String sql, [List<dynamic> arguments])  {
    return database.then((db) {
      return db.rawQuery(sql, arguments);
    }).then((finds) {
      return finds.map((find) => dGenerator.dFromJson(find)).toList();
    });
  }

  Future<D> findOne(String sql, [List<dynamic> arguments]) {
    return findAll(sql, arguments)
        .then((list) {
          if (list == null || list.isEmpty) {
            return null;
          }
          return list[0];
    });
  }

  Future<bool> contains(String sql, [List<dynamic> arguments]) {
    return findOne(sql, arguments).then((find) => find != null);
  }

}

// import 'dart:async';

// import 'package:cookie_jar/cookie_jar.dart';
// import 'package:dio/dio.dart';
// import 'package:dio_cookie_manager/dio_cookie_manager.dart';
// import 'package:thyi/src/util/util_log.dart';

// class Thyi {
//   Dio dio;

//   Interceptors get interceptors {
//     return dio.interceptors;
//   }

//   Thyi(String baseUrl, {bool enableLog = true}) {
//     isLogEnable = enableLog;
//     dio = Dio(BaseOptions(baseUrl: baseUrl));
//     interceptors.add(CookieManager(CookieJar()));
//   }

// }

// /// 代表某条api
// class ApiMethod {
//   String method;
//   String path = '';
//   Map<String, String> headers = {};
//   Map<String, String> fields = {};
//   Map<String, String> queries = {};

//   ApiMethod(this.method, this.path, {this.headers, this.fields, this.queries});

//   Future<String> send(Thyi thyi) {
//     var options = Options();
//     var dio = thyi.dio;

//     if (headers != null && headers.isNotEmpty) {
//       options.headers.addAll(headers);
//     }

//     if (isGet()) {
//       logi('url: ${dio.options.baseUrl}, path: ${path}');
//       return dio.get<String>(path, queryParameters: queries, options: options)
//         .then((response) => _parseResponse(response));
//     }
//     else if (isPost()) {
//       logi('url: ${dio.options.baseUrl}, path: ${path} fileds: ${fields}');
//       return dio.post<String>(path, queryParameters: queries, options: options, data: fields)
//         .then((response) => _parseResponse(response));
//     } else {
//       return Future.error('for now unsupport http method; ${method}');
//     }

//   }

//   String _parseResponse(Response response) {
//     var rst = response.data.toString();
//     logi("response: $rst");
//     return rst;
//   }


//   bool isGet() {
//     return "GET" == method.toUpperCase();
//   }

//   bool isPost() {
//     return "POST" == method.toUpperCase();
//   }

// }