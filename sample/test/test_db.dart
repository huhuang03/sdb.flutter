
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sdb_sample/scr/user.dart';

void main() {
  test("test inert", () async {
    WidgetsFlutterBinding.ensureInitialized();
    dao.insert(User("ton", "hu", 800));
    List<User> users = await dao.findAll("select * from user");
    print(users);
  });
}