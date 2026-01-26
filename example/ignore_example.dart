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

// To run this example:
//     $ cd example
//     $ dart ignore_example.dart

import 'dart:io';

import 'package:codemod/codemod.dart';

/// Example suggestor that adds a comment before each function.
Stream<Patch> addCommentBeforeFunction(FileContext context) async* {
  final text = context.sourceText;
  final pattern = RegExp(r'\bString\s+\w+\s*\(\)');
  
  for (final match in pattern.allMatches(text)) {
    yield Patch('// Function found\n', match.start, match.start);
  }
}

void main(List<String> args) async {
  exitCode = await runInteractiveCodemod(
    ['ignore_example_fixtures/example.dart'],
    addCommentBeforeFunction,
    args: args,
  );
}
