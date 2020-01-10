import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:test/test.dart';


void main() {
  test('calculate', () {
    // final animal = Class((b) => b
    //   ..name = 'Animal'
    //   ..extend = refer('Organism')
    //   ..methods.add(Method((b) => b
    //     ..returns = refer('Foo', 'package:foo')
    //     ..name = 'eat'
    //     ..body = const Code("print('Yum');"))));
    literal("hello");
    final aa = refer("AAA").newInstance([], {"a": literal('{"a": aa}')});
    final emitter =  DartEmitter(Allocator.simplePrefixing());;
    print(DartFormatter().format('${aa.accept(emitter)}'));
  });
}
