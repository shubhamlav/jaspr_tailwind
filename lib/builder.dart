import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Builds `web/*.tw.css` into `web/*.css` with the Tailwind CSS v4 CLI.
///
/// See CHANGELOG.md 0.3.7 for what changed since 0.3.6 (Tailwind v3).
Builder buildStylesheet(BuilderOptions options) => TailwindBuilder(options);

class TailwindBuilder implements Builder {
  TailwindBuilder(this.options);

  final BuilderOptions options;

  /// Package-relative directories scanned for class names.
  static const _sourceDirs = ['lib', 'web'];

  /// Package-relative directories carved out of v4's automatic source
  /// detection. The `@source` globs below already limit scanning to `lib` and
  /// `web`; this keeps everything else v4 would otherwise pick up excluded.
  static const _excludedDirs = ['packages'];

  /// Smallest stylesheet this builder accepts, in bytes. v4 exits 0 on a
  /// stylesheet it does not understand, emitting only its licence banner
  /// (~170 B), so the check discriminates on size: valid output measured
  /// ~8.7 kB (~7.4 kB minified) on v4.3.0 with ~12 classes. Do not raise this —
  /// a young site can minify below any "reasonable" floor and then every build
  /// fails.
  static const minOutputBytes = 1024;

  /// Extra CLI flags from `build.yaml`'s
  /// `defaults.release_options.tailwindcss`.
  ///
  /// `BuilderOptions.config` is dynamic, so it may arrive as a scalar or a
  /// list.
  List<String> get _extraArgs {
    final configured = options.config['tailwindcss'];
    return switch (configured) {
      null => const <String>[],
      final Iterable<Object?> it => it.map((e) => '$e').toList(),
      final Object? other => ['$other'],
    };
  }

  @override
  Future<void> build(BuildStep buildStep) async {
    // Rebuild whenever a Dart or content file changes.
    final dartAssets =
        await buildStep.findAssets(Glob('{lib,web}/**/*.dart')).toList();
    final contentAssets =
        await buildStep.findAssets(Glob('content/**/*.{md,yaml}')).toList();
    await Future.wait(
      [...dartAssets, ...contentAssets].map(buildStep.canRead),
    );

    final outputId =
        buildStep.inputId.changeExtension('').changeExtension('.css');

    final packageRoot = Directory.current.path;

    // v4 resolves `@source` relative to the stylesheet and the CLI reads a copy
    // in a temp dir, so the globs must be absolute paths built from
    // `Directory.current`, which the builder already assumes is the package
    // root (upstream used it for `--config`).
    //
    // Appended, not prepended: v4 requires `@import` to come first, so a
    // directive above it would void the import.
    final prepared =
        StringBuffer(await buildStep.readAsString(buildStep.inputId));
    if (!prepared.toString().endsWith('\n')) prepared.writeln();
    for (final dir in _sourceDirs) {
      prepared.writeln(
          '@source "${_cssString(p.join(packageRoot, dir, '**', '*.dart'))}";');
    }
    for (final dir in _excludedDirs) {
      prepared
          .writeln('@source not "${_cssString(p.join(packageRoot, dir))}";');
    }

    final workDir = await Directory.systemTemp.createTemp('jaspr_tailwind.');
    try {
      final inputFile = File(p.join(workDir.path, 'input.css'))
        ..writeAsStringSync(prepared.toString());
      final outputFile = File(p.join(workDir.path, 'output.css'));

      final args = <String>[
        '--input',
        inputFile.path,
        '--output',
        outputFile.path,
        ..._extraArgs,
      ];

      // runInShell joins the args unquoted, and `args` holds only the temp file
      // paths: a space in TMPDIR splits them and fails obscurely.
      final ProcessResult result;
      try {
        result = await Process.run(
          'tailwindcss',
          args,
          runInShell: true,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
      } on ProcessException catch (e) {
        throw StateError(
          'jaspr_tailwind: could not run the `tailwindcss` CLI. Install the '
          'standalone Tailwind CSS v4 binary on PATH; `tailwindcss --help` '
          'must list --minify and must not list --content.\n'
          'Underlying error: ${e.message}',
        );
      }

      // On success Tailwind writes its banner ("Done in 11ms") to stderr.
      final stderrText = '${result.stderr}'.trim();
      if (stderrText.isNotEmpty) {
        log.info('jaspr_tailwind: $stderrText');
      }

      // runInShell maps a missing binary to 127 and a non-executable one to
      // 126 on POSIX; Windows reports other codes. Every one is non-zero.
      if (result.exitCode != 0) {
        throw StateError(
          'jaspr_tailwind: `tailwindcss` failed for ${buildStep.inputId} '
          '(exit ${result.exitCode}).\n'
          'Command: tailwindcss ${args.join(' ')}\n'
          'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
      }

      if (!outputFile.existsSync()) {
        throw StateError(
          'jaspr_tailwind: `tailwindcss` exited 0 but wrote no output for '
          '${buildStep.inputId}.',
        );
      }

      final byteLength = await outputFile.length();
      if (byteLength < minOutputBytes) {
        throw StateError(
          'jaspr_tailwind: `tailwindcss` exited 0 but produced only '
          '$byteLength bytes for ${buildStep.inputId} (floor: '
          '$minOutputBytes). No utilities were generated -- almost always a '
          'wrong `@source` path, or a stylesheet still using the v3 '
          '`@tailwind` directives.\n'
          'Output:\n${outputFile.readAsStringSync()}',
        );
      }

      await buildStep.writeAsString(outputId, outputFile.readAsStringSync());
    } finally {
      if (workDir.existsSync()) {
        workDir.deleteSync(recursive: true);
      }
    }
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        'web/{{file}}.tw.css': ['web/{{file}}.css'],
      };
}

/// Renders [path] as a CSS string literal: posix separators, with `"` and `\`
/// escaped. `@source` values are CSS strings, so the quoting matters.
String _cssString(String path) => p.posix
    .joinAll(p.split(path))
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"');
