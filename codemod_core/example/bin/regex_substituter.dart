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
///     $ dart regex_substituter.dart
library dart_codemod.example.regex_substituter;

import 'package:codemod_core/codemod_core.dart';
import 'package:path/path.dart';

// ignore: avoid_relative_lib_imports
import '../lib/src/suggestors/regex_substituter.dart';

void main(List<String> args) async {
  final pg = PatchGenerator([regexSubstituter]);
  final changeSets = pg
      .generate(paths: [join('fixtures', 'regex_substituter', 'pubspec.yaml')]);

  await for (final changeSet in changeSets) {
    /// Change .apply to .applyAndSave to write the changes to disk
    changeSet.apply();
    // changeSet.applyAndSave();
  }
}
