import 'dart:convert';
import 'dart:io';

import 'package:jaspr_tailwind/src/package_root.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('jt_root_');
    File(p.join(dir.path, '.dart_tool', 'package_config.json'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        jsonEncode({
          'configVersion': 2,
          'packages': [
            {'name': 'app', 'rootUri': '../', 'packageUri': 'lib/'},
            {'name': 'other', 'rootUri': '/abs/other/', 'packageUri': 'lib/'},
          ],
        }),
      );
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('resolves own package', () async {
    expect(await packageRootOf('app', dir), dir.path);
  });

  test('resolves another package', () async {
    expect(await packageRootOf('other', dir), '/abs/other');
  });

  test('unknown package', () async {
    expect(await packageRootOf('nope', dir), isNull);
  });
}
