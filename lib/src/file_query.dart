import 'dart:io';

import 'package:path/path.dart' as path;

import 'run_interactive_codemod.dart' show runInteractiveCodemod;
import 'util.dart' show pathLooksLikeCode;

/// A representation of query that should return a particular set of files.
///
/// Required as an argument for [runInteractiveCodemod].
///
/// Use the named constructors to easily build file queries:
///     FileQuery.cwd(pathFilter: (path) => path.endsWith('.md'));
///     FileQuery.dir('example/', recursive: true);
///     FileQuery.single('lib/src/foo.dart');
abstract class FileQuery {
  /// Constructs a query for files in the current working directory.
  ///
  /// If [followLinks] is true, symlinks will be followed, otherwise they will
  /// be skipped.
  ///
  /// If [recursive] is true, the query will recurse into subdirectories.
  ///
  /// If a [pathFilter] is provided, it will be called for each file path. Any
  /// file path for which the filter does not return true will be excluded.
  factory FileQuery.cwd({
    bool followLinks = false,
    bool Function(String path) pathFilter,
    bool recursive = false,
  }) =>
      _FilesInDirQuery(path.current,
          followLinks: followLinks,
          pathFilter: pathFilter,
          recursive: recursive);

  /// Constructs a query for files in the directory located at [dirPath].
  ///
  /// If [followLinks] is true, symlinks will be followed, otherwise they will
  /// be skipped.
  ///
  /// If [recursive] is true, the query will recurse into subdirectories.
  ///
  /// If a [pathFilter] is provided, it will be called for each file path. Any
  /// file path for which the filter does not return true will be excluded.
  factory FileQuery.dir(
    String dirPath, {
    bool followLinks = false,
    bool Function(String path) pathFilter,
    bool recursive = false,
  }) =>
      _FilesInDirQuery(dirPath,
          followLinks: followLinks,
          pathFilter: pathFilter,
          recursive: recursive);

  /// Constructs a simple query that returns a single [filePath].
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
    yield filePath;
  }

  @override
  String get target => filePath;

  @override
  bool get targetExists => FileSystemEntity.isFileSync(filePath);
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

  _FilesInDirQuery(this.dirPath,
      {this.followLinks = false, this.pathFilter, this.recursive = false});

  @override
  Iterable<String> generateFilePaths() sync* {
    final dir = Directory(dirPath);
    for (final fse
        in dir.listSync(followLinks: followLinks, recursive: recursive)) {
      if (fse is! File) {
        continue;
      }
      final filePath = path.relative(fse.absolute.path);
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
  String get target => dirPath;

  @override
  bool get targetExists => FileSystemEntity.isDirectorySync(dirPath);
}
