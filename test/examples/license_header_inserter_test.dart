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
import 'package:test/test.dart';

import '../util.dart';

final String licenseHeader = '''
// Lorem ispum license.
// 2018-2019
''';

class LicenseHeaderInserter implements Suggestor {
  @override
  Stream<Patch> generatePatches(FileContext context) async* {
    if (context.sourceText.trimLeft().startsWith(licenseHeader)) return;

    yield context.patch(
      // Text to insert.
      licenseHeader,
      // Start offset.
      // 0 means "insert at the beginning of the file."
      0,
      // End offset.
      // Using the same offset as the start offset here means that the patch
      // is being inserted at this point instead of replacing a span of text.
      0,
    );
  }
}

void main() {
  group('Examples: LicenseHeaderInserter', () {
    test('inserts missing header', () async {
      final context = await fileContextForTest('foo.dart', 'library foo;');
      final expectedOutput = '${licenseHeader}library foo;';
      expect(await applySuggestor(context, LicenseHeaderInserter()),
          expectedOutput);
    });
  });
}
