import 'dart:io';

import 'package:package_config/package_config.dart';
import 'package:path/path.dart' as p;

/// Finds the root directory of [package] through the package config found
/// from [searchFrom] or one of its parents.
///
/// This works when `build_runner` runs from a pub workspace root, where the
/// current directory is not the package's own root. Returns null when there
/// is no package config or it does not list [package].
Future<String?> packageRootOf(String package, Directory searchFrom) async {
  final config = await findPackageConfig(searchFrom);
  final root = config?[package]?.root;
  if (root == null) return null;
  return p.normalize(root.toFilePath());
}
