// Copyright 2019 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
