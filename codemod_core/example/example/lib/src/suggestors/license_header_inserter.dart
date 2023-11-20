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

/// To run this example:
///     $ cd example
///     $ dart license_header_inserter.dart
library dart_codemod.example.license_header_inserter;

import 'package:codemod_core/codemod_core.dart';

const String licenseHeader = '''
// Lorem ispum license.
// 2018-2019
''';

/// Suggestor that generates patches to insert a license header at the beginning
/// of every file that is missing such a header.
Stream<Patch> licenseHeaderInserter(FileContext context) async* {
  // Skip if license header already exists.
  if (context.sourceText.trimLeft().startsWith(licenseHeader)) {
    return;
  }

  yield const Patch(
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
