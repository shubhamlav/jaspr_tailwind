import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

import 'src/package_root.dart';
import 'src/stylesheet.dart';
import 'src/tailwind_cli.dart';

/// Creates the [TailwindBuilder] that `build.yaml` registers.
Builder buildStylesheet(BuilderOptions options) => TailwindBuilder(options);

/// The Tailwind major version of each CLI, probed once per build.
///
/// Holds futures so build steps running at the same time share one probe.
final _versionCache = Resource<Map<String, Future<int?>>>(
  () => <String, Future<int?>>{},
);

/// build_runner keeps a failed step's result until one of its inputs changes,
/// and the CLI itself is not a build input.
const _retryHint =
    'After fixing this, save a Dart or CSS file, or run '
    '`dart run build_runner clean`, to build again.';

const _configNames = [
  'tailwind.config.js',
  'tailwind.config.cjs',
  'tailwind.config.mjs',
  'tailwind.config.ts',
];

/// Builds `web/**/*.css` from each `web/**/*.tw.css` entrypoint with the
/// Tailwind CSS v4 CLI.
///
/// The CLI runs on the stylesheet where it lives in the package, so relative
/// `@import` and `@source` paths and `@plugin` packages from `node_modules`
/// resolve as they do outside the build. The CLI writes into a temporary
/// directory, and the result becomes the build output.
class TailwindBuilder implements Builder {
  /// Creates a builder configured by [options].
  TailwindBuilder(this.options);

  /// Options from `build.yaml`: `cli` picks the Tailwind CLI, and
  /// `tailwindcss` holds extra CLI flags such as `--minify`.
  final BuilderOptions options;

  @override
  Map<String, List<String>> get buildExtensions => const {
    'web/{{file}}.tw.css': ['web/{{file}}.css'],
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final outputId = inputId.changeExtension('').changeExtension('.css');

    // Record inputs before any check can stop this step: build_runner reruns a
    // failed step only when one of its recorded inputs changes.
    await _trackSources(buildStep);

    final root = await packageRootOf(inputId.package, Directory.current);
    if (root == null) {
      log.severe(
        'Cannot find the root of package ${inputId.package} in the '
        'package config. Run `dart pub get` and build again.',
      );
      return;
    }

    final cli = resolveTailwindCli(
      cliOption: options.config['cli'] as String?,
      packageRoot: root,
      isWindows: Platform.isWindows,
      isOnPath: _isOnPath,
    );
    if (cli == null) {
      log.severe(
        'Tailwind CSS CLI not found for ${inputId.package}. '
        'Install it one of these ways:\n'
        '  - npm i -D tailwindcss @tailwindcss/cli daisyui  (recommended, '
        'run in $root)\n'
        '  - put the standalone tailwindcss binary on PATH: '
        'https://tailwindcss.com/blog/standalone-cli\n'
        '  - set the `cli` option in build.yaml to npx, standalone, or the '
        'path of a Tailwind CLI\n'
        '$_retryHint',
      );
      return;
    }

    final int? major;
    try {
      final cache = await buildStep.fetchResource(_versionCache);
      major = await cache.putIfAbsent(
        cli.toString(),
        () => _probeMajorVersion(cli, root),
      );
    } on ProcessException catch (e) {
      log.severe('Cannot run the Tailwind CSS CLI `$cli`: ${e.message}');
      return;
    }
    if (major == null) {
      log.warning(
        'Cannot tell which Tailwind CSS version `$cli` is. '
        'jaspr_tailwind needs Tailwind CSS v4.',
      );
    } else if (major < 4) {
      log.severe(
        'jaspr_tailwind needs Tailwind CSS v4; `$cli` is v$major. '
        'Install Tailwind CSS v4 or point the `cli` option at it. '
        '$_retryHint',
      );
      return;
    }

    final input = p.joinAll([root, ...p.posix.split(inputId.path)]);
    final inputFile = File(input);
    if (!inputFile.existsSync()) {
      log.severe(
        'Cannot find $input. Tailwind CSS runs on the stylesheet '
        'file itself, so it must exist in the package.',
      );
      return;
    }
    final css = await inputFile.readAsString();
    if (usesV3Directives(css)) {
      log.severe(
        '${inputId.path} uses Tailwind CSS v3 directives, which '
        'Tailwind CSS v4 does not build. Replace the @tailwind directives '
        'with @import "tailwindcss"; (see '
        'https://tailwindcss.com/docs/upgrade-guide).',
      );
      return;
    }
    if (!hasConfigDirective(css)) _warnIgnoredConfig(root, input);

    final tempDir = await Directory.systemTemp.createTemp('jaspr_tailwind_');
    try {
      final output = File(p.join(tempDir.path, 'out.css'));
      final ProcessResult result;
      try {
        result = await _run(cli, [
          '-i',
          input,
          '-o',
          output.path,
          ...splitCliOptions(options.config['tailwindcss']),
          '--cwd',
          root,
        ], root);
      } on ProcessException catch (e) {
        log.severe('Cannot run the Tailwind CSS CLI `$cli`: ${e.message}');
        return;
      }

      if (result.exitCode != 0 || !output.existsSync()) {
        log.severe(
          'Tailwind CSS failed on ${inputId.path} '
          '(exit code ${result.exitCode}).\n'
          'stdout:\n${result.stdout}\nstderr:\n${result.stderr}',
        );
        return;
      }
      final bytes = await output.readAsBytes();
      if (!hasCssRules(utf8.decode(bytes, allowMalformed: true))) {
        log.severe(
          'Tailwind produced no CSS rules for ${inputId.path}. '
          'Start the stylesheet with @import "tailwindcss"; and check that '
          'your classes appear in files under $root.',
        );
        return;
      }
      await buildStep.writeAsBytes(outputId, bytes);
    } finally {
      await tempDir.delete(recursive: true);
    }
  }

  /// Records the files Tailwind scans as inputs of this step, so that
  /// editing one of them rebuilds the CSS.
  ///
  /// CSS files built by this builder are skipped: reading an output of this
  /// builder from one of its own steps is a dependency cycle.
  Future<void> _trackSources(BuildStep buildStep) async {
    final css = await buildStep.findAssets(Glob('{lib,web}/**.css')).toList();
    final entrypoints = {
      for (final asset in css)
        if (asset.path.endsWith('.tw.css')) asset.path,
    };
    final sources = [
      ...await buildStep.findAssets(Glob('{lib,web}/**.dart')).toList(),
      ...await buildStep.findAssets(Glob('content/**')).toList(),
      for (final asset in css)
        if (!entrypoints.contains(_entrypointFor(asset.path))) asset,
    ];
    await Future.wait(sources.map(buildStep.canRead));
  }

  /// Warns when [root] holds a Tailwind JS config that the stylesheet at
  /// [input] does not load; Tailwind CSS v4 reads it only through `@config`.
  void _warnIgnoredConfig(String root, String input) {
    for (final name in _configNames) {
      final config = p.join(root, name);
      if (!File(config).existsSync()) continue;
      final relative = p
          .relative(config, from: p.dirname(input))
          .replaceAll(r'\', '/');
      log.warning(
        'Tailwind CSS v4 ignores $name unless the stylesheet loads '
        'it. Add @config "$relative"; to ${p.basename(input)} to keep it.',
      );
      return;
    }
  }
}

/// The `.tw.css` entrypoint that would build [cssPath].
String _entrypointFor(String cssPath) =>
    '${cssPath.substring(0, cssPath.length - '.css'.length)}.tw.css';

Future<ProcessResult> _run(TailwindCli cli, List<String> args, String root) {
  final (executable, arguments) = commandLine(
    cli,
    args,
    isWindows: Platform.isWindows,
  );
  return Process.run(executable, arguments, workingDirectory: root);
}

Future<int?> _probeMajorVersion(TailwindCli cli, String root) async {
  final result = await _run(cli, ['--help'], root);
  return parseTailwindMajorVersion('${result.stdout}\n${result.stderr}');
}

bool _isOnPath(String name) {
  try {
    final result = Process.runSync(Platform.isWindows ? 'where' : 'which', [
      name,
    ]);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
