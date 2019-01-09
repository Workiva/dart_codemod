@TestOn('vm')
import 'package:codemod/codemod.dart';
import 'package:source_span/source_span.dart';
import 'package:test/test.dart';

final String licenseHeader = '''
// Lorem ispum license.
// 2018-2019
''';

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

void main() {
  group('Examples: LicenseHeaderInserter', () {
    test('inserts missing header', () {
      final sourceFile = SourceFile.fromString('library foo;');
      final expectedOutput = '${licenseHeader}library foo;' '';
      final patches = LicenseHeaderInserter().generatePatches(sourceFile);
      expect(patches, hasLength(1));
      expect(applyPatches(sourceFile, patches), expectedOutput);
    });

    test('should skip if header is already present', () {
      expect(LicenseHeaderInserter().shouldSkip('${licenseHeader}library foo;'),
          isTrue);
    });
  });
}
