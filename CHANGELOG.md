## [0.2.0](https://github.com/Workiva/dart_codemod/compare/0.1.5...0.2.0)

- **Breaking Change:** remove the `FileQuery` class. The
`runInteractiveCodemod()` function now expects an `Iterable<File>` instead of a
`FileQuery`. This is intended to simplify consumption; [`package:glob`][glob]
can be used to easily query for the desired files.

- **Breaking Change:** remove `createPathFilter()` - this was used with `FileQuery` and can be replaced by custom logic now that
`runInteractiveCodemod()` accepts an `Iterable<File>`.

- **Breaking Change:** remove `isDartFile()` - use [`package:glob`][glob]
instead to target files with the `.dart` extension (e.g. `Glob('**.dart')`).

- Add a `filePathsFromGlob()` utility function that takes a `Glob` instance and
returns the file paths matched by the glob, but filtered to exclude hidden
files (e.g. files in `.dart_tool/`). This is intended to serve the most common
use case of running codemods on Dart projects, e.g.:

    ```dart
    runInteractiveCodemod(
      filePathsFromGlob(Glob('**.dart', recursive: true)),
      suggestor);
    ```

[glob]: https://pub.dev/packages/glob

- Widen Analyzer dependency range to include `0.39.x`.

- Make `Patch` override `operator ==` and `hashCode` so that instances can be
compared for equality. If two `Patch` instances target the same span in the same
file and have the same `updatedText`, they are considered equal.

- `AstVisitingSuggestorMixin` now de-duplicates patches suggested for each
source file. This can be useful for recursive and generalizing AST visitors that
may end up suggesting duplicate patches in parts of the AST that get handled by
multiple `visit` methods.

- Improve the error/help output when overlapping patches are found.

## [0.1.5](https://github.com/Workiva/dart_codemod/compare/0.1.4...0.1.5)

- Widen Analyzer dependency range from `^0.37.0` to `>=0.37.0 <0.39.0`.

- Exclude `build/` folder when a codemod gets run.

## [0.1.4](https://github.com/Workiva/dart_codemod/compare/0.1.3...0.1.4)

- Prompts the user to either skip overlapping patches or quit when they are found. 

## [0.1.3](https://github.com/Workiva/dart_codemod/compare/0.1.2...0.1.3)

- Codemod authors can now augment the help output and the changes required
  output via `runInteractiveCodemod()` and `runInteractiveCodemodSequence()`
  using the optional `additionalHelpOutput` and `changesRequiredOutput` params.

  - If `additionalHelpOutput` is given, it will be printed to stderr after the
    default help output when the codemod is run with the `-h|--help` flag.

  - If `changesRequiredOutput` is given, it will be printed to stderr after the
    default output when the codemod is run with the `--fail-on-changes` flag and
    changes are in fact required.

## [0.1.2](https://github.com/Workiva/dart_codemod/compare/0.1.1...0.1.2)

- Fix a typing issue with the `AggregateSuggestor`'s constructor param.

- Add tests for `AggregateSuggestor` and `AstVisitingSuggestorMixin`

## [0.1.1](https://github.com/Workiva/dart_codemod/compare/0.1.0...0.1.1)

- Update `pubspec.yaml` for initial OSS release.

## [0.1.0](https://github.com/Workiva/dart_codemod/compare/11a1c55...0.1.0)

- Initial tag.
