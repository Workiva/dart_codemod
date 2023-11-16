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

import 'package:glob/glob.dart';
import 'package:glob/list_local_fs.dart';
import 'package:path/path.dart' as p;

/// Returns file paths matched by [glob] and filtered to exclude any of the
/// following by default:
/// - Hidden files (filename starts with `.`)
/// - Files in hidden directories (dirname starts with `.`)
///
/// If [ignoreHiddenFiles] is false, these hidden files will be included.
Iterable<String> filePathsFromGlob(Glob glob, {bool? ignoreHiddenFiles}) {
  var files = glob.listSync().whereType<File>();
  if (ignoreHiddenFiles ?? true) {
    files = files.where(isNotHiddenFile);
  }
  return files.map((file) => file.path);
}

bool isHiddenFile(File file) {
  final path = p.normalize(file.path);
  return p.basename(path).startsWith('.') ||
      p.split(path).any((segment) => segment.startsWith('.'));
}

bool isNotHiddenFile(File file) => !isHiddenFile(file);

bool isDartHiddenFile(File file) {
  final path = p.normalize(file.path);
  return p.basename(path) == '.packages' ||
      p.split(path).contains('.dart_tool');
}

bool isNotDartHiddenFile(File file) => !isDartHiddenFile(file);
