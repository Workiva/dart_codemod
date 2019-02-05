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
