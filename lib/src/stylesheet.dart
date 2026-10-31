final _v3Directive = RegExp(r'@tailwind\s+(base|components)\b');
final _configDirective = RegExp(r'@config\s');
final _comment = RegExp(r'/\*[\s\S]*?\*/');

/// Whether [css] uses the Tailwind v3 `@tailwind base` or
/// `@tailwind components` directives, which Tailwind v4 does not support.
bool usesV3Directives(String css) => _v3Directive.hasMatch(css);

/// Whether [css] loads a JavaScript config through the v4 `@config`
/// directive.
bool hasConfigDirective(String css) => _configDirective.hasMatch(css);

/// Whether [css] holds anything besides comments and whitespace.
///
/// Tailwind writes only its licence banner when it finds nothing to build,
/// for example when given v3 input.
bool hasCssRules(String css) => css.replaceAll(_comment, '').trim().isNotEmpty;
