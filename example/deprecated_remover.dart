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
///     $ dart deprecated_remover.dart
library dart_codemod.example.deprecated_remover;

import 'dart:io';

import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';
import 'package:glob/glob.dart';

/// Suggestor that generates deletion patches for all deprecated declarations
/// (i.e. classes, constructors, variables, methods, etc.).
class DeprecatedRemover extends GeneralizingAstVisitor
    with AstVisitingSuggestorMixin {
  static bool isDeprecated(AnnotatedNode node) =>
      node.metadata.any((m) => m.name.name.toLowerCase() == 'deprecated');

  @override
  visitDeclaration(Declaration node) {
    if (isDeprecated(node)) {
      // Remove the node by replacing the span from its start offset to its end
      // offset with an empty string.
      yieldPatch(node.offset, node.end, '');
    }
  }
}

void main(List<String> args) {
  exitCode = runInteractiveCodemod(
    Glob('deprecated_remover_fixtures/**.dart').listSync().whereType<File>(),
    DeprecatedRemover(),
    args: args,
  );
}
