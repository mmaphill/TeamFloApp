import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/moderation_service.dart';

/// REPORT AND BLOCK: shared dialogs used by the feed and the comments sheet,
/// so posts and comments behave the same way.
class ModerationDialogs {
  ModerationDialogs._();

  static const List<String> reasons = [
    'Spam',
    'Harassment or bullying',
    'Hate speech',
    'Nudity or sexual content',
    'Violence or threats',
    'Something else',
  ];

  static void _showMessage(BuildContext context, String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? AppColors.error : null),
    );
  }

  /// Asks for a reason, then sends the report.
  /// Leave [commentId] null to report the post itself.
  static Future<void> report(
      BuildContext context, {
        required String postId,
        String? commentId,
        required String authorId,
        required String authorName,
        required String text,
        int mediaCount = 0,
      }) async {
    final result = await showDialog<({String reason, String details})>(
      context: context,
      builder: (_) => _ReportDialog(what: commentId == null ? 'post' : 'comment'),
    );
    if (result == null) return;

    final error = await ModerationService().report(
      postId: postId,
      commentId: commentId,
      contentAuthorId: authorId,
      contentAuthorName: authorName,
      contentText: text,
      mediaCount: mediaCount,
      reason: result.reason,
      details: result.details,
    );

    if (!context.mounted) return;
    _showMessage(
      context,
      error ?? 'Thanks. Gym staff will review this report.',
      isError: error != null,
    );
  }

  /// Confirms, then blocks the member.
  static Future<void> block(
      BuildContext context, {
        required String userId,
        required String name,
      }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $name?'),
        content: const Text(
          'You won\'t see their posts or comments, and you won\'t be notified '
              'when they tag you. They won\'t be told.\n\n'
              'You can unblock them any time from Profile > Blocked members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final error = await ModerationService().blockUser(userId, name);
    if (!context.mounted) return;
    _showMessage(context, error ?? '$name is blocked', isError: error != null);
  }
}

class _ReportDialog extends StatefulWidget {
  final String what; // 'post' or 'comment'
  const _ReportDialog({required this.what});

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Report this ${widget.what}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting it? Gym staff will review it.'),
            const SizedBox(height: 8),
            ...ModerationDialogs.reasons.map(
                  (reason) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  _reason == reason
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _reason == reason ? context.colors.primary : null,
                ),
                title: Text(reason),
                onTap: () => setState(() => _reason = reason),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.pop(
            context,
            (reason: _reason!, details: _detailsController.text),
          ),
          child: const Text('Send report'),
        ),
      ],
    );
  }
}