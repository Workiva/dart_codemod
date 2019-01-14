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

@TestOn('vm')
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'package:codemod/src/file_query.dart';

const dirPath = 'test_fixtures/file_query/';

void main() {
  group('FileQuery', () {
    group('.dir()', () {
      test('defaults to the current working directory', () {
        final query = FileQuery.dir();
        expect(
          p.canonicalize(query.target),
          p.canonicalize(p.current),
        );
      });

      test('lists files in dir', () {
        final query = FileQuery.dir(path: dirPath);
        expect(
          query.generateFilePaths(),
          unorderedEquals([
            p.join(dirPath, 'file.dart'),
            p.join(dirPath, 'file.yaml'),
          ]),
        );
      });

      test('follows and includes symbolic links if followLinks=true', () {
        final query =
            FileQuery.dir(followLinks: true, path: dirPath, recursive: true);
        expect(
          query.generateFilePaths(),
          unorderedEquals([
            p.join(dirPath, 'file.dart'),
            p.join(dirPath, 'file.yaml'),
            p.join(dirPath, 'sub', 'file.dart'),
            p.join(dirPath, 'symlink.dart'),
          ]),
        );
      });

      test('lists files in dir and all sub-dirs if recursive=true', () {
        final query = FileQuery.dir(path: dirPath, recursive: true);
        expect(
          query.generateFilePaths(),
          unorderedEquals([
            p.join(dirPath, 'file.dart'),
            p.join(dirPath, 'file.yaml'),
            p.join(dirPath, 'sub', 'file.dart'),
          ]),
        );
      });

      test('should filter out dotfiles', () {
        final query = FileQuery.dir(path: dirPath, recursive: true);
        expect(
          query.generateFilePaths(),
          isNot(contains(p.join(dirPath, '.dotfile'))),
        );
      });

      test('should filter results by given `pathFilter`', () {
        bool pathFilter(String path) => path.endsWith('.dart');
        final query = FileQuery.dir(path: dirPath, pathFilter: pathFilter);
        expect(
          query.generateFilePaths(),
          unorderedEquals([
            p.join(dirPath, 'file.dart'),
          ]),
        );
      });

      test('target should return the dir path', () {
        final query = FileQuery.dir(path: dirPath);
        expect(query.target, dirPath);
      });

      test('targetExists should return true if the dir exists', () {
        final query = FileQuery.dir(path: dirPath);
        expect(query.targetExists, isTrue);
      });

      test('targetExists should return false if the dir does not exist', () {
        final query = FileQuery.dir(path: 'does/not/exist/');
        expect(query.targetExists, isFalse);
      });
    });

    group('.single()', () {
      test('should list the single given file path', () {
        final path = p.join(dirPath, 'file.dart');
        final query = FileQuery.single(path);
        expect(query.generateFilePaths(), equals([path]));
      });

      test('target should return the file path', () {
        final path = p.join(dirPath, 'file.dart');
        final query = FileQuery.single(path);
        expect(query.target, path);
      });

      test('targetExists should return true if the file exists', () {
        final path = p.join(dirPath, 'file.dart');
        final query = FileQuery.single(path);
        expect(query.targetExists, isTrue);
      });

      test('targetExists should return false if the file does not exist', () {
        final query = FileQuery.single('does/not/exist.dart');
        expect(query.targetExists, isFalse);
      });

      test('targetExists should return false if the path is not a file', () {
        final query = FileQuery.single(dirPath);
        expect(query.targetExists, isFalse);
      });
    });
  });
}
