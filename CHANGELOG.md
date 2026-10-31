## 0.4.0

Breaking:

- Supports Tailwind CSS v4 only. A stylesheet with `@tailwind base` or
  `@tailwind components`, or a v3 CLI, now fails the build with a migration
  hint.
- The builder no longer passes `--content` or `--config`. Load a
  `tailwind.config.js` with `@config` from the stylesheet; the build warns when
  a config file is not loaded.
- Requires Dart 3.7 or later.

Fixed:

- Installs on Dart 3.13 and later (#19): `build_modules` is gone. It capped the
  SDK below 3.13 and collided with `build_web_compilers` 4.5.0 and later
  ("module_library outputs collide").
- Tailwind CSS v4 builds no longer produce an empty stylesheet.
- The CLI runs on the stylesheet inside the project, so relative `@import` and
  `@source` paths and `@plugin "daisyui"` resolve.
- A missing CLI, a CLI error, or output with no CSS rules fails the build with
  the CLI's output, instead of passing silently.

Added:

- Uses `node_modules/.bin/tailwindcss` from the package when present, then
  `tailwindcss` on the PATH.
- `cli` option: `npx`, `standalone`, or the path of a Tailwind CLI.
- `dart run build_runner build --workspace` support: the package root comes
  from the package config.
- Rebuilds when CSS files in `web/` or files in `content/` change.

Thanks to @ekrem-qb (#8), @lukehutch (#14), @Markzipan (#18), and @Dimoshka
(#20), whose pull requests found these problems and shaped this release.

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
