import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/mention_model.dart';

class MentionTextRenderer {
  /// Build a RichText widget with mentions styled in AppColors.mention (blue)
  /// Only applies styling to mentions with valid indices
  static RichText buildMentionText(
      String text,
      List<Mention> mentions, {
        TextStyle? baseStyle,
        TextStyle? mentionStyle,
      }) {
    baseStyle ??= const TextStyle(
      color: AppColors.darkText,
      fontSize: 16,
    );

    mentionStyle ??= const TextStyle(
      color: AppColors.mention,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    if (mentions.isEmpty) {
      return RichText(text: TextSpan(text: text, style: baseStyle));
    }

    // Filter out invalid mentions (out of bounds or incorrect)
    final validMentions = mentions.where((m) {
      return m.startIndex >= 0 &&
          m.endIndex <= text.length &&
          m.startIndex < m.endIndex;
    }).toList();

    if (validMentions.isEmpty) {
      return RichText(text: TextSpan(text: text, style: baseStyle));
    }

    // Sort mentions by startIndex to process in order
    validMentions.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (var mention in validMentions) {
      // Add text before mention
      if (mention.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, mention.startIndex),
          style: baseStyle,
        ));
      }

      // Add mention text (styled)
      spans.add(TextSpan(
        text: text.substring(mention.startIndex, mention.endIndex),
        style: mentionStyle,
      ));

      lastIndex = mention.endIndex;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Simpler version: just return TextSpan (use in Text.rich())
  static TextSpan buildMentionSpan(
      String text,
      List<Mention> mentions, {
        TextStyle? baseStyle,
        TextStyle? mentionStyle,
      }) {
    baseStyle ??= const TextStyle(
      color: AppColors.darkText,
      fontSize: 16,
    );

    mentionStyle ??= const TextStyle(
      color: AppColors.mention,
      fontWeight: FontWeight.bold,
      fontSize: 16,
    );

    if (mentions.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // Filter out invalid mentions (out of bounds or incorrect)
    final validMentions = mentions.where((m) {
      return m.startIndex >= 0 &&
          m.endIndex <= text.length &&
          m.startIndex < m.endIndex;
    }).toList();

    if (validMentions.isEmpty) {
      return TextSpan(text: text, style: baseStyle);
    }

    // Sort mentions by startIndex
    validMentions.sort((a, b) => a.startIndex.compareTo(b.startIndex));

    final spans = <TextSpan>[];
    int lastIndex = 0;

    for (var mention in validMentions) {
      if (mention.startIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, mention.startIndex),
          style: baseStyle,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(mention.startIndex, mention.endIndex),
        style: mentionStyle,
      ));

      lastIndex = mention.endIndex;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: baseStyle,
      ));
    }

    return TextSpan(children: spans);
  }
}