import 'package:json_annotation/json_annotation.dart';
import 'package:sdb/sdb.dart';
import 'package:sdb_sample/scr/user.sdb.dart';

part 'user.g.dart';

@TABLE("user")
@JsonSerializable(explicitToJson: true)
class User {
  String firstName;
  String secondName;
  int age;

  User(this.firstName, this.secondName, this.age);

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  @override
  String toString() {
    return 'User{firstName: $firstName, secondName: $secondName, age: $age}';
  }

}

var dao = $UserDao();

class UserDstDao extends SdbDao<User> {

  UserDstDao() : super(TABLE("user"), DGenerator(createSql: (d) {return "";}, dFromJson: (json) => User.fromJson(json), dToJson: (d) => d.toJson()));

}
