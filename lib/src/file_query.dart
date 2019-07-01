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

import 'package:path/path.dart' as p;

import 'run_interactive_codemod.dart' show runInteractiveCodemod;
import 'util.dart' show pathLooksLikeCode;

String cwdOverride;

/// A representation of a query that should return a particular set of files.
///
/// Required as an argument for [runInteractiveCodemod].
///
/// Use the named constructors to easily build file queries:
///     FileQuery.dir(pathFilter: (path) => path.endsWith('.md'));
///     FileQuery.dir(path: 'example/', recursive: true);
///     FileQuery.single('lib/src/foo.dart');
abstract class FileQuery {
  /// Constructs a query for files in the directory located at [path], or the
  /// current working directory if no [path] is given.
  ///
  /// If [followLinks] is true, symlinks will be followed, otherwise they will
  /// be skipped.
  ///
  /// If [recursive] is true, the query will recurse into subdirectories.
  ///
  /// If a [pathFilter] is provided, it will be called for each file path. Any
  /// file path for which the filter does not return true will be excluded.
  factory FileQuery.dir({
    String path,
    bool followLinks = false,
    bool Function(String path) pathFilter,
    bool recursive = false,
  }) =>
      _FilesInDirQuery(
          path: path,
          followLinks: followLinks,
          pathFilter: pathFilter,
          recursive: recursive);

  /// Constructs a query that returns a single [filePath].
  factory FileQuery.single(String filePath) => new _SingleFileQuery(filePath);

  /// The primary target for this query (either a path to a file or to a parent
  /// directory).
  ///
  /// Used for error messaging when the target cannot be found.
  String get target;

  /// Returns all of the file paths found by this query, taking into account the
  /// [followLinks] and [recursive] options as well as the optional
  /// [pathFilter].
  Iterable<String> generateFilePaths();

  /// Whether or not the primary target exists.
  ///
  /// If this is false, the query will be unable to find any file paths.
  bool get targetExists;
}

/// A simple query that returns a single file path.
class _SingleFileQuery implements FileQuery {
  // The single file path being targeted.
  final String filePath;

  _SingleFileQuery(this.filePath);

  @override
  Iterable<String> generateFilePaths() sync* {
    yield target;
  }

  @override
  String get target {
    if (cwdOverride != null && p.isRelative(filePath)) {
      return p.normalize(p.join(cwdOverride, filePath));
    }
    return filePath;
  }

  @override
  bool get targetExists => FileSystemEntity.isFileSync(target);

  @override
  String toString() => '<_SingleFileQuery: $target>';
}

/// A query for all files in a directory.
class _FilesInDirQuery implements FileQuery {
  /// The directory within which to search for files.
  final String dirPath;

  /// Whether or not symbolic links should be followed.
  final bool followLinks;

  /// Filter function to conditionally filter out file paths found within the
  /// given directory.
  ///
  /// May be null.
  final bool Function(String path) pathFilter;

  /// Whether or not to recurse into subdirectories when listing files.
  final bool recursive;

  _FilesInDirQuery(
      {String path,
      this.followLinks = false,
      this.pathFilter,
      this.recursive = false})
      : dirPath = path ?? p.current;

  @override
  Iterable<String> generateFilePaths() sync* {
    final dir = Directory(target);
    for (final fse
        in dir.listSync(followLinks: followLinks, recursive: recursive)) {
      if (fse is! File) {
        continue;
      }
      final filePath = p.relative(fse.absolute.path);
      if (!pathLooksLikeCode(filePath)) {
        continue;
      }
      if (pathFilter != null && pathFilter(filePath) != true) {
        continue;
      }

      yield filePath;
    }
  }

  @override
  String get target {
    if (cwdOverride != null && p.isRelative(dirPath)) {
      return p.normalize(p.join(cwdOverride, dirPath));
    }
    return dirPath;
  }

  @override
  bool get targetExists => FileSystemEntity.isDirectorySync(target);

  @override
  String toString() => '<_FilesInDirQuery: $target (filter: ${pathFilter != null}, followLinks: $followLinks, recursive: $recursive)>';
}
