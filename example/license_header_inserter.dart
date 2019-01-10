/// To run this example:
///     $ cd example
///     $ dart license_header_inserter.dart
library dart_codemod.example.license_header_inserter;

import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

final String licenseHeader = '''
// Lorem ispum license.
// 2018-2019
''';

/// Suggestor that generates patches to insert a license header at the beginning
/// of every file that is missing such a header.
class LicenseHeaderInserter implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) =>
      sourceFileContents.trimLeft().startsWith(licenseHeader);

  @override
  Iterable<Patch> generatePatches(SourceFile sourceFile) sync* {
    yield Patch(
      sourceFile,
      // The span across which the patch should be applied.
      sourceFile.span(
        // Start offset.
        // 0 means "insert at the beginning of the file."
        0,
        // End offset.
        // Using the same offset as the start offset here means that the patch
        // is being inserted at this point instead of replacing a span of text.
        0,
      ),
      // Text to insert.
      licenseHeader,
    );
  }
}

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    FileQuery.dir(path: 'license_header_fixtures/', pathFilter: isDartFile),
    LicenseHeaderInserter(),
    args: args,
  );
}
