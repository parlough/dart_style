// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:dart_style/src/ast_extensions.dart';

import '../constants.dart';
import '../piece/piece.dart';
import '../piece/sequence.dart';
import 'piece_factory.dart';

/// Incrementally builds a [SequencePiece], including handling comments and
/// newlines that may appear before, between, or after its contents.
///
/// Comments are handled specially here so that we can give them better
/// formatting than we would be able to if we treated all comments generally.
///
/// Most comments appear around statements in a block, members in a class, or
/// at the top level of a file. For those, we treat them essentially like
/// separate statements inside the sequence. This lets us gracefully handle
/// indenting them and supporting blank lines around them the same way we handle
/// other statements or members in a sequence.
class SequenceBuilder {
  final PieceFactory _visitor;

  /// The series of elements in the sequence.
  final List<SequenceElement> _elements = [];

  /// Whether a blank line should be allowed after the current element.
  bool _allowBlank = false;

  SequenceBuilder(this._visitor);

  SequencePiece build() => SequencePiece(_elements);

  /// Adds [piece] to this sequence.
  ///
  /// The caller should have already called [addCommentsBefore()] with the
  /// first token in [piece].
  void add(Piece piece, {int? indent, bool allowBlankAfter = true}) {
    _elements.add(SequenceElement(indent ?? Indent.none, piece));

    _allowBlank = allowBlankAfter;
  }

  /// Visits [node] and adds the resulting [Piece] to this sequence, handling
  /// any comments or blank lines that appear before it.
  void visit(AstNode node, {int? indent}) {
    addCommentsBefore(node.firstNonCommentToken);
    _visitor.visit(node);
    add(_visitor.pieces.split(), indent: indent);
  }

  /// Appends a blank line before the next piece in the sequence.
  void addBlank() {
    if (_elements.isEmpty) return;
    if (!_allowBlank) return;
    _elements.last.blankAfter = true;
  }

  /// Writes any comments appearing before [token] to the sequence.
  ///
  /// Comments between sequence elements get special handling where comments
  /// on their own line become standalone sequence elements.
  void addCommentsBefore(Token token) {
    var comments = _visitor.takeCommentsBefore(token);

    // Edge case: if we require a blank line, but there exists one between
    // some of the comments, or after the last one, then we don't need to
    // enforce one before the first comment. Example:
    //
    //     library foo;
    //     // comment
    //
    //     class Bar {}
    //
    // Normally, a blank line is required after `library`, but since there is
    // one after the comment, we don't need one before it. This is mainly so
    // that commented out directives stick with their preceding group.
    if (comments.containsBlank && _elements.isNotEmpty) {
      _elements.last.blankAfter = false;
    }

    for (var i = 0; i < comments.length; i++) {
      var comment = comments[i];
      if (_elements.isNotEmpty && comments.isHanging(i)) {
        // Attach the comment to the previous token.
        _visitor.space();
        _visitor.pieces.writeComment(comment, hanging: true);
      } else {
        // Write the comment as its own sequence piece.
        _visitor.pieces.writeComment(comment);
        if (comments.linesBefore(i) > 1) {
          // Always preserve a blank line above sequence-level comments.
          _allowBlank = true;
          addBlank();
        }

        add(_visitor.pieces.split());
      }
    }

    // Write a blank before the token if there should be one.
    if (comments.linesBeforeNextToken > 1) addBlank();
  }
}
