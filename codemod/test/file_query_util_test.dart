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
import 'dart:io';

import 'package:codemod/codemod.dart';
import 'package:test/test.dart';

void main() {
  group('isHiddenFile', () {
    test('returns false for non-hidden files', () {
      expect(isHiddenFile(File('foo/bar_/baz')), isFalse); // relative
      expect(isHiddenFile(File('/root/foo/bar_')), isFalse); // absolute
    });

    test('returns true when filename starts with "."', () {
      expect(isHiddenFile(File('foo/.bar')), isTrue); // relative
      expect(isHiddenFile(File('/root/foo/.bar')), isTrue); // absolute
    });

    test('returns true when any path segment starts with "."', () {
      expect(isHiddenFile(File('foo/.bar/baz')), isTrue); // relative
      expect(isHiddenFile(File('/root/foo/.bar/baz')), isTrue); // absolute
    });

    test('normalizes "." and ".." path segments', () {
      // relative
      expect(isHiddenFile(File('foo/./bar')), isFalse);
      expect(isHiddenFile(File('foo/../bar')), isFalse);
      // absolute
      expect(isHiddenFile(File('/root/foo/./bar')), isFalse);
      expect(isHiddenFile(File('/root/foo/../bar')), isFalse);
    });
  });

  group('isDartHiddenFile', () {
    test('returns false for non-dart-hidden files', () {
      expect(isDartHiddenFile(File('foo/bar_/baz')), isFalse); // relative
      expect(isDartHiddenFile(File('/root/foo/bar_')), isFalse); // absolute
    });

    test('returns true for ".packages"', () {
      expect(isDartHiddenFile(File('foo/.packages')), isTrue); // relative
      expect(isDartHiddenFile(File('/root/foo/.packages')), isTrue); // absolute
    });

    test('returns true when any path segment is ".dart_tool"', () {
      expect(isDartHiddenFile(File('foo/.dart_tool/baz')), isTrue); // relative
      expect(isDartHiddenFile(File('/root/foo/.dart_tool/baz')),
          isTrue); // absolute
    });

    test('normalizes "." and ".." path segments', () {
      // relative
      expect(isDartHiddenFile(File('foo/./bar')), isFalse);
      expect(isDartHiddenFile(File('foo/../bar')), isFalse);
      // absolute
      expect(isDartHiddenFile(File('/root/foo/./bar')), isFalse);
      expect(isDartHiddenFile(File('/root/foo/../bar')), isFalse);
    });
  });
}
