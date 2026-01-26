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

import 'package:glob/glob.dart';
import 'package:path/path.dart' as p;

/// Configuration for file filtering.
class FileFilterConfig {
  /// Glob patterns for files to include.
  ///
  /// If empty, all files are included (subject to exclude patterns).
  final List<String> includePatterns;

  /// Glob patterns for files to exclude.
  ///
  /// Exclude patterns take precedence over include patterns.
  final List<String> excludePatterns;

  /// Whether to ignore hidden files and directories.
  final bool ignoreHidden;

  /// Whether to ignore Dart-specific hidden files (.dart_tool, .packages).
  final bool ignoreDartHidden;

  const FileFilterConfig({
    this.includePatterns = const [],
    this.excludePatterns = const [],
    this.ignoreHidden = true,
    this.ignoreDartHidden = true,
  });

  /// Creates a [FileFilterConfig] from a map (e.g., from YAML).
  factory FileFilterConfig.fromMap(Map<String, dynamic> map) {
    return FileFilterConfig(
      includePatterns:
          (map['include'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      excludePatterns:
          (map['exclude'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      ignoreHidden: map['ignore_hidden'] as bool? ?? true,
      ignoreDartHidden: map['ignore_dart_hidden'] as bool? ?? true,
    );
  }
}

/// Filters file paths based on include/exclude patterns and hidden file settings.
class FileFilter {
  final FileFilterConfig _config;
  final List<Glob> _includeGlobs;
  final List<Glob> _excludeGlobs;

  FileFilter(this._config)
    : _includeGlobs = _config.includePatterns
          .map((pattern) => Glob(pattern))
          .toList(),
      _excludeGlobs = _config.excludePatterns
          .map((pattern) => Glob(pattern))
          .toList();

  /// Checks if a file path should be included.
  bool shouldInclude(String filePath) {
    final normalizedPath = p.normalize(filePath);

    // Check hidden files
    if (_config.ignoreHidden) {
      final segments = p.split(normalizedPath);
      if (segments.any((segment) => segment.startsWith('.'))) {
        return false;
      }
    }

    // Check Dart-specific hidden files
    if (_config.ignoreDartHidden) {
      final segments = p.split(normalizedPath);
      if (segments.contains('.dart_tool') ||
          p.basename(normalizedPath) == '.packages') {
        return false;
      }
    }

    // Check exclude patterns (take precedence)
    for (final excludeGlob in _excludeGlobs) {
      if (excludeGlob.matches(normalizedPath)) {
        return false;
      }
    }

    // Check include patterns
    if (_includeGlobs.isNotEmpty) {
      for (final includeGlob in _includeGlobs) {
        if (includeGlob.matches(normalizedPath)) {
          return true;
        }
      }
      return false;
    }

    return true;
  }

  /// Filters a list of file paths.
  Iterable<String> filterFiles(Iterable<String> filePaths) {
    return filePaths.where(shouldInclude);
  }
}
