import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';

const String licenseHeader = '''
// All rights reserved.
// 2018-2019
''';

class LicenseHeaderInserter implements Suggestor {
  @override
  bool shouldSkip(String sourceFileContents) =>
      sourceFileContents.startsWith(licenseHeader);

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

void main(List<String> args) => runInteractiveCodemod(
      FileQuery.cwd(pathFilter: isDartFile),
      LicenseHeaderInserter(),
      args: args,
    );
