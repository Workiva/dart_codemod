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

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:codemod/codemod.dart';
import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

Future<FileContext> fileContextForTest(String name, String sourceText) async {
  await d.file(name, sourceText).create();
  final path = p.canonicalize(p.join(d.sandbox, name));
  final collection = AnalysisContextCollection(includedPaths: [path]);
  return FileContext(path, collection);
}

/// Defines a test and wraps the [body] in a call to [overrideAnsiOutput] that
/// forces ANSI output to be enabled. This allows the test to verify that
/// certain output is highlighted correctly even when running in environments
/// where ANSI output would normally be disabled (like CI).
void testWithAnsi(String description, void Function() body) {
  test(description, () => overrideAnsiOutput(true, body));
}
