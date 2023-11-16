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

const ansiEscapeLiteral = '\x1B';

/// Clears the terminal screen of all content.
const ansiClearScreen = '$ansiEscapeLiteral[2J';

/// Moves the cursor back to the "home" position (top-left).
const ansiCursorHome = '$ansiEscapeLiteral[H';
