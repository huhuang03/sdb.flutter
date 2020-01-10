import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/sdb_generator.dart';

export 'package:json_serializable/json_serializable.dart';

Builder sdbBuilder(BuilderOptions options) => LibraryBuilder(SdbGenerator(), generatedExtension: '.sdb.dart');

