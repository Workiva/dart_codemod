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

export 'src/aggregate_suggestor.dart' show AggregateSuggestor;
export 'src/file_context.dart' show FileContext;
export 'src/file_query_util.dart'
    show
        filePathsFromGlob,
        isHiddenFile,
        isNotHiddenFile,
        isDartHiddenFile,
        isNotDartHiddenFile;
export 'src/patch.dart' show Patch;
export 'src/run_interactive_codemod.dart'
    show runInteractiveCodemod, runInteractiveCodemodSequence;
export 'src/suggestor.dart' show Suggestor;
export 'src/suggestor_mixins.dart'
    show AstVisitingSuggestor, ElementVisitingSuggestor;
export 'src/util.dart' show applyPatches, applySuggestor;
