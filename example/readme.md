This directory contains several example codemods:

- [License header inserter](/example/license_header_inserter.dart)

  A simple example that inserts license text at the top of a file.

- [Regex substituter](/example/regex_substituter.dart)

  A simple example that uses a RegExp to make replacements over all matches.

- [Remove deprecated elements](/example/deprecated_remover.dart)

  Uses an `AstVisitor` from `package:analyzer` to remove all elements annotated
  with `@deprecated`.

- [Suggest `isEven` or `isOdd`](/example/is_even_or_odd_suggestor.dart)

  Uses an `AstVisitor` and fully resolves all source code information and types
  for a more advanced modification.
