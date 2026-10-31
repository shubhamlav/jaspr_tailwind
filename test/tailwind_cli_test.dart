import 'dart:io';

import 'package:jaspr_tailwind/src/tailwind_cli.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Resolves the CLI against a fresh temp package root.
///
/// [withLocalBin] creates `node_modules/.bin/tailwindcss` (`.cmd` when
/// [windows]) in that root; [onPath] is the answer for every PATH lookup.
TailwindCli? resolve({
  String? cli,
  bool onPath = false,
  bool withLocalBin = false,
  bool windows = false,
}) {
  final root = Directory.systemTemp.createTempSync('jt_cli_');
  addTearDown(() => root.deleteSync(recursive: true));
  if (withLocalBin) {
    final name = windows ? 'tailwindcss.cmd' : 'tailwindcss';
    File(
      p.join(root.path, 'node_modules', '.bin', name),
    ).createSync(recursive: true);
  }
  return resolveTailwindCli(
    cliOption: cli,
    packageRoot: root.path,
    isWindows: windows,
    isOnPath: (_) => onPath,
  );
}

void main() {
  group('resolveTailwindCli', () {
    test('npx option', () {
      final cli = resolve(cli: 'npx')!;
      expect(cli.executable, 'npx');
      expect(cli.leadingArgs, ['--yes', '@tailwindcss/cli']);
    });

    test('path option is used as is', () {
      expect(resolve(cli: '/opt/tw')!.executable, '/opt/tw');
    });

    test('standalone on PATH', () {
      expect(
        resolve(cli: 'standalone', onPath: true)!.executable,
        'tailwindcss',
      );
    });

    test('standalone off PATH is null', () {
      expect(resolve(cli: 'standalone'), isNull);
    });

    test('local bin wins over PATH', () {
      expect(
        resolve(withLocalBin: true, onPath: true)!.executable,
        endsWith(p.join('node_modules', '.bin', 'tailwindcss')),
      );
    });

    test('windows picks .cmd', () {
      expect(
        resolve(withLocalBin: true, windows: true)!.executable,
        endsWith('tailwindcss.cmd'),
      );
    });

    test('PATH fallback', () {
      expect(resolve(onPath: true)!.executable, 'tailwindcss');
    });

    test('nothing found', () {
      expect(resolve(), isNull);
    });
  });

  group('commandLine', () {
    const npm = TailwindCli(
      r'C:\Users\Jane Doe\site\node_modules\.bin\tailwindcss.cmd',
    );

    test('runs the CLI directly off Windows', () {
      final (executable, args) = commandLine(
        const TailwindCli('npx', ['--yes', '@tailwindcss/cli']),
        ['-i', 'in.css'],
        isWindows: false,
      );
      expect(executable, 'npx');
      expect(args, ['--yes', '@tailwindcss/cli', '-i', 'in.css']);
    });

    test('starts cmd with call first on Windows', () {
      final (executable, args) = commandLine(npm, [
        '-i',
        'in.css',
      ], isWindows: true);
      expect(executable, 'cmd.exe');
      expect(args, ['/d', '/c', 'call', npm.executable, '-i', 'in.css']);
    });
  });

  group('parseTailwindMajorVersion', () {
    test('v4 help', () {
      expect(parseTailwindMajorVersion('≈ tailwindcss v4.3.3\n'), 4);
    });

    test('v3 help', () {
      expect(parseTailwindMajorVersion('\x1B[1mtailwindcss v3.4.17\x1B[0m'), 3);
    });

    test('unknown help', () {
      expect(parseTailwindMajorVersion('usage: foo'), isNull);
    });
  });

  group('splitCliOptions', () {
    test('split options', () {
      expect(splitCliOptions(' --minify  --optimize '), [
        '--minify',
        '--optimize',
      ]);
    });

    test('null options', () {
      expect(splitCliOptions(null), isEmpty);
    });

    test('list options', () {
      expect(splitCliOptions(['--minify', '--optimize']), [
        '--minify',
        '--optimize',
      ]);
    });
  });
}
