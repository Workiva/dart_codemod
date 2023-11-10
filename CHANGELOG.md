## [1.2.0](https://github.com/Workiva/dart_codemod/compare/1.1.0...1.2.0)

- Add `PackageContextForTest` to `package:codemod/test.dart` to help test
suggestors that require a fully resolved AST from the analyzer (for example:
suggestors using the `AstVisitingSuggestor` mixin with `shouldResolveAst`
enabled).

## [1.1.0](https://github.com/Workiva/dart_codemod/compare/1.0.11...1.1.0)

- Compatibility with Dart 3 and analyzer 6.

## [1.0.11](https://github.com/Workiva/dart_codemod/compare/1.0.10...1.0.11)

- Widen analyzer dependency range to include v3, v4, and v5.

## [1.0.10](https://github.com/Workiva/dart_codemod/compare/1.0.9...1.0.10)

- Update analyzer dependency to v2

## [1.0.4](https://github.com/Workiva/dart_codemod/compare/1.0.3...1.0.4)

- Switch to replacements for deprecated Dart CLIs

## [1.0.3](https://github.com/Workiva/dart_codemod/compare/1.0.2...1.0.3)

- Fix wildcard in GitHub CI

## [1.0.2](https://github.com/Workiva/dart_codemod/compare/1.0.1...1.0.2)

- Raise Dart SDK minimum to 2.11.0

## [1.0.1](https://github.com/Workiva/dart_codemod/compare/1.0.0...1.0.1)

- Include file path in error message when parsing a Dart file fails.

## [1.0.0](https://github.com/Workiva/dart_codemod/compare/0.3.0...1.0.0)

- Null-safety release.
- `AstVisitingSuggestor.context` will throw a `StateError` if accessed outside
one of the visitor methods.

## [0.3.1](https://github.com/Workiva/dart_codemod/compare/0.3.0...0.3.1)

- Fix invalid file path error on windows when applying patches.

## [0.3.0](https://github.com/Workiva/dart_codemod/compare/0.2.0...0.3.0)

- **Breaking:** `runInteractiveCodemod` and `runInteractiveCodemodSequence` are
both now async.

- **Breaking:** `Suggestor` is now a function typedef instead of a class.
Addtionally, it takes the new `FileContext` type as its only parameter
(previously the `generatePatches` method took a `SourceFile`) and now must
return a `Stream<Patch>` instead of `Iterable<Patch>`.

    If you were extending `Suggestor`, you can either change the class to a
    function like so:

    ```diff
      final String licenseHeader = '...';

    - class LicenseHeaderInserter implements Suggestor {
    -   @override
    -   bool shouldSkip(String sourceFileContents) =>
    -       sourceFileContents.trimLeft().startsWith(licenseHeader);
    -
    -   @override
    -   Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    -     yield Patch(sourceFile, sourceFile.span(0, 0), licenseHeader);
    -   }
    - }

    + Stream<Patch> licenseHeaderInserter(FileContext context) async* {
    +   // Skip if license header already exists.
    +   if (context.sourceText.trimLeft().startsWith(licenseHeader)) return;
    +
    +   yield Patch(licenseHeader, 0, 0);
    + }
    ```

    Or rename the `generatePatches()` method to `call()` so that the
    class is callable like a function:

    ```diff
      final String licenseHeader = '...';

    - class LicenseHeaderInserter implements Suggestor {
    + class LicenseHeaderInserter {
    -   @override
        bool shouldSkip(String sourceFileContents) =>
            sourceFileContents.trimLeft().startsWith(licenseHeader);

    -   @override
    -   Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    +   Stream<Patch> call(FileContext context) async* {
    +     if (shouldSkip(context.sourceText)) return;
    -     yield Patch(sourceFile, sourceFile.span(0, 0), licenseHeader);
    +     yield Patch(licenseHeader, 0, 0);
        }
      }
    ```

- **Breaking:** Simplify the `Patch` class to now only encapsulate the updated
text, start offset, and end offset.

    ```diff
    - yield Patch(sourceFile, sourceFile.span(5, 10), 'updated text');
    + yield Patch('updated text', 5, 10);
    ```

- **Breaking:** Rename `AstVisitingSuggestorMixin` to `AstVisitingSuggestor`
since the `Mixin` suffix was redundant.

- **Breaking:** Remove `AggregateSuggestor` class in favor of an
`aggregate(Iterable<Suggestor> suggestors)` function.

- **Breaking:** Move `applyPatches` from the main `package:codemod/codemod.dart`
entrypoint to the new `package:codemod/test.dart` entrypoint to make its
intended usage clear.

- Add a `shouldResolveAst(FileContext context)` method to
`AstVisitingSuggestor`. Defaults to false (since resolving is slower), but can
be overridden to true if the fully resolved AST is needed.

  - Add example of such a codemod: see [example/is_even_or_odd_suggestor.dart](/example/is_even_or_odd_suggestor.dart)

- Add `package:codemod/test.dart` entrypoint for testing suggestors. This
entrypoint exports three functions:

  - `Future<FileContext> fileContextForTest(String name, String contents)`
  - `void expectSuggestorGeneratesPatches(Suggestor suggestor, FileContext context, dynamic resultMatcher)`
  - `String applyPatches(SourceFile sourceFile, Iterable<Patch> patches)`

    The first two should be sufficient for testing most suggestors.

- Use GitHub Actions for CI (remove Travis CI).

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
