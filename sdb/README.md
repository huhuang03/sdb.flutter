# How to use

To use this package, you should use the `json_serializable` too.
- add to pubspec.yaml
```yaml
dependency:
  json_annotation:
  sdb:

dev_dependency:
  sdb_generator:
  json_serializable:
  build_runner:
```

- First define a bean class
``` dart 
class User {
    var username = "";
    var nickname = "";
}
```

- Add the `json_serializable` dependency
The `json_serializble` usage please see it's doc. And then add JsonSerialzble to User class

``` dart 
@JsonSerializable()
class User {
    var username = "";
    var nickname = "";
}
```

- Then define the TABLE annotation.

```dart
@TABLE("user")
@JsonSerializable()
class User {
    var username = "";
    var nickname = "";
}

```

- Run `flutter pub run build_runner build` to generate Dao class, which names `$UserDao` in file `you_file.sdb.dart`.

# Some notes
- Because this package usually use the `json_serializable` to generate the `bean <-> json` method. 
So this package export the json_serializable too.