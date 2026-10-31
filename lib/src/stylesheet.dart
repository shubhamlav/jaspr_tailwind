final _v3Directive = RegExp(r'@tailwind\s+(base|components)\b');
final _v4Import = RegExp(r'''@import\s+(["'])tailwindcss\1''');
final _configDirective = RegExp(r'@config\s');
final _comment = RegExp(r'/\*[\s\S]*?\*/');

String _withoutComments(String css) => css.replaceAll(_comment, '');

/// Whether [css] is a Tailwind v3 stylesheet: it uses the `@tailwind base` or
/// `@tailwind components` directives and does not `@import "tailwindcss"`.
///
/// Comments are ignored, so a directive left in a comment after migrating
/// does not count.
bool usesV3Directives(String css) {
  final code = _withoutComments(css);
  return _v3Directive.hasMatch(code) && !_v4Import.hasMatch(code);
}

/// Whether [css] loads a JavaScript config through the v4 `@config`
/// directive. Comments are ignored.
bool hasConfigDirective(String css) =>
    _configDirective.hasMatch(_withoutComments(css));

/// Whether [css] holds anything besides comments and whitespace.
///
/// Tailwind writes only its licence banner when it finds nothing to build,
/// for example when given v3 input.
bool hasCssRules(String css) => _withoutComments(css).trim().isNotEmpty;
