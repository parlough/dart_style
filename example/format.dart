// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:dart_style/dart_style.dart';
import 'package:dart_style/src/constants.dart';
import 'package:dart_style/src/debug.dart' as debug;
import 'package:dart_style/src/testing/test_file.dart';

void main(List<String> args) {
  // Enable debugging so you can see some of the formatter's internal state.
  // Normal users do not do this.
  debug.traceChunkBuilder = true;
  debug.traceLineWriter = true;
  debug.traceSplitter = true;
  debug.useAnsiColors = true;
  debug.tracePieceBuilder = true;
  debug.traceSolver = true;

  runTest('selection/selection.stmt', 2);
}

void formatStmt(String source, {required bool tall, int pageWidth = 80}) {
  runFormatter(source, pageWidth, tall: tall, isCompilationUnit: false);
}

void formatUnit(String source, {required bool tall, int pageWidth = 80}) {
  runFormatter(source, pageWidth, tall: tall, isCompilationUnit: true);
}

void runFormatter(String source, int pageWidth,
    {required bool tall, required bool isCompilationUnit}) {
  try {
    var formatter = DartFormatter(
        pageWidth: pageWidth,
        experimentFlags: [if (tall) tallStyleExperimentFlag]);

    String result;
    if (isCompilationUnit) {
      result = formatter.format(source);
    } else {
      result = formatter.formatStatement(source);
    }

    drawRuler('before', pageWidth);
    print(source);
    drawRuler('after', pageWidth);
    print(result);
  } on FormatterException catch (error) {
    print(error.message());
  }
}

void drawRuler(String label, int width) {
  var padding = ' ' * (width - label.length - 1);
  print('$label:$padding|');
}

/// Runs the formatter test starting on [line] at [path] inside the "test"
/// directory.
Future<void> runTest(String path, int line,
    {int pageWidth = 40, bool tall = true}) async {
  var testFile = await TestFile.read(path);
  var formatTest = testFile.tests.firstWhere((test) => test.line == line);

  var formatter = DartFormatter(
      pageWidth: testFile.pageWidth,
      indent: formatTest.leadingIndent,
      fixes: formatTest.fixes,
      experimentFlags: tall
          ? const ['inline-class', tallStyleExperimentFlag]
          : const ['inline-class']);

  var actual = formatter.formatSource(formatTest.input);

  // The test files always put a newline at the end of the expectation.
  // Statements from the formatter (correctly) don't have that, so add
  // one to line up with the expected result.
  var actualText = actual.textWithSelectionMarkers;
  if (!testFile.isCompilationUnit) actualText += '\n';

  var expectedText = formatTest.output.textWithSelectionMarkers;

  print('$path ${formatTest.description}');
  drawRuler('before', pageWidth);
  print(formatTest.input.textWithSelectionMarkers);
  if (actualText == expectedText) {
    drawRuler('result', pageWidth);
    print(actualText);
  } else {
    print('FAIL');
    drawRuler('expected', pageWidth);
    print(expectedText);
    drawRuler('actual', pageWidth);
    print(actualText);
  }
}
