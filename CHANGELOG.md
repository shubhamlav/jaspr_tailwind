## 0.3.7

- Builder identity unchanged — a drop-in upgrade.
- Source globs are injected as absolute `@source` directives appended to the
  stylesheet, replacing `--content`/`--config` and the `@tailwind` directives,
  all removed in v4.
- Requires the v4 CLI and `@import "tailwindcss";` in the entry stylesheet;
  input still using the v3 `@tailwind` directives fails the size floor.
- The `Process.run` result is checked: exit code, output existence and
  stdout/stderr. In 0.3.6 the result was discarded, so every Tailwind failure
  was silent.
- Output must be at least 1 KiB (`minOutputBytes`): v4 exits 0 on a stylesheet
  it does not understand, emitting only its licence banner.
- `canRead` covers `content/**/*.{md,yaml}`, so Markdown and YAML edits
  invalidate the CSS.
- Dropped `build_modules` (scratch space unused) and `build_runner` (no codegen).
- `build`: `^4.0.0` → `^4.0.7`; 4.0.8+ needs `analyzer >=13.3.0` but
  `jaspr_builder` pins `^12.1.0`, so consuming projects fail to resolve.

## 0.3.6

- Transfer ownership
- Add IntelliSense support in README.md

## 0.3.5

- fix: package dependency check failing for projects that are part of a dart workspace

## 0.3.4

- Updated dependencies to support the latest version of Jaspr.

## 0.3.3

- Transfer ownership

## 0.3.2

- Update logo and website links.

## 0.3.1

- Fixed execution of tailwind cli by adding `runInShell: true`.

## 0.3.0

- Added minify option to tailwind in release mode.
- Made the content section of the `tailwind.config.js` file active at build time.

## 0.2.0

- **BREAKING**: Changed tailwind command to use the [standalone cli](https://tailwindcss.com/blog/standalone-cli)
instead of npx. Make sure this is installed and included in your PATH. (see
the updated README for setup instructions).

## 0.1.1

- Fixed configuration paths on windows.

## 0.1.0

- Initial version.
