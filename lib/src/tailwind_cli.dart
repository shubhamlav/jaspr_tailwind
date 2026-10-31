import 'dart:io';

import 'package:path/path.dart' as p;

const _binary = 'tailwindcss';

/// A Tailwind CSS command line: the program to start and the arguments that
/// go before Tailwind's own flags.
class TailwindCli {
  /// Creates a CLI that starts [executable] with [leadingArgs] first.
  const TailwindCli(this.executable, [this.leadingArgs = const []]);

  /// The program to start: a path, or a name looked up on `PATH`.
  final String executable;

  /// Arguments placed before Tailwind's flags, such as
  /// `--yes @tailwindcss/cli` when the CLI runs through `npx`.
  final List<String> leadingArgs;

  @override
  String toString() => [executable, ...leadingArgs].join(' ');
}

/// Picks the Tailwind CLI for the package at [packageRoot].
///
/// [cliOption] is the builder's `cli` option: `npx` runs `@tailwindcss/cli`
/// through npx, `standalone` uses the `tailwindcss` binary on `PATH`, and any
/// other value is the path of the CLI to run, used as is. Without the option,
/// the package's own `node_modules/.bin/tailwindcss` (`tailwindcss.cmd` when
/// [isWindows]) wins over `tailwindcss` on `PATH`. [isOnPath] answers whether
/// a program name is found on `PATH`.
///
/// Returns null when no CLI is found.
TailwindCli? resolveTailwindCli({
  required String? cliOption,
  required String packageRoot,
  required bool isWindows,
  required bool Function(String name) isOnPath,
}) {
  switch (cliOption) {
    case 'npx':
      return const TailwindCli('npx', ['--yes', '@tailwindcss/cli']);
    case 'standalone':
      return isOnPath(_binary) ? const TailwindCli(_binary) : null;
    case final String path:
      return TailwindCli(path);
  }
  final local = p.join(
    packageRoot,
    'node_modules',
    '.bin',
    isWindows ? '$_binary.cmd' : _binary,
  );
  if (File(local).existsSync()) return TailwindCli(local);
  if (isOnPath(_binary)) return const TailwindCli(_binary);
  return null;
}

final _ansiEscape = RegExp(r'\x1B\[[0-9;]*m');
final _versionLine = RegExp(r'tailwindcss v(\d+)\.');

/// Reads the major version from the output of `tailwindcss --help`.
///
/// Returns null when the output names no version.
int? parseTailwindMajorVersion(String helpOutput) {
  final match = _versionLine.firstMatch(helpOutput.replaceAll(_ansiEscape, ''));
  return match == null ? null : int.parse(match.group(1)!);
}

/// Turns the builder's `tailwindcss` option into CLI arguments.
///
/// A string is split on whitespace, a list gives one argument per item, and
/// null gives no arguments.
List<String> splitCliOptions(Object? option) {
  if (option == null) return const [];
  if (option is List) return [for (final item in option) '$item'];
  return '$option'
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
}
