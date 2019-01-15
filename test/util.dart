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

import 'dart:io';

import 'package:io/ansi.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Copies the contents of the [source] directory to [dest].
///
/// If [dest] does not exist, it will be created. Only copies files and
/// directories; ignores links.
void copyDirectory(Directory source, Directory dest) {
  if (!dest.existsSync()) {
    dest.createSync(recursive: true);
  }

  for (final entity in source.listSync(recursive: true)) {
    if (FileSystemEntity.isDirectorySync(entity.path)) {
      Directory orig = entity;
      final path = p.join(
        dest.path,
        p.relative(orig.path, from: source.path),
      );
      final copy = Directory(path);
      if (!copy.existsSync()) {
        copy.createSync(recursive: true);
      }
    } else if (FileSystemEntity.isFileSync(entity.path)) {
      File orig = entity;
      final path = p.join(
        dest.path,
        p.relative(orig.path, from: source.path),
      );
      final copy = File(path);
      copy.createSync(recursive: true);
      copy.writeAsBytesSync(orig.readAsBytesSync());
    }
  }
}

/// Defines a test and wraps the [body] in a call to [overrideAnsiOutput] that
/// forces ANSI output to be enabled. This allows the test to verify that
/// certain output is highlighted correctly even when running in environments
/// where ANSI output would normally be disabled (like CI).
void testWithAnsi(String description, body()) {
  test(description, () => overrideAnsiOutput(true, body));
}
