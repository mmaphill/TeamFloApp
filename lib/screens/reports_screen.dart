import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../services/moderation_service.dart';
import 'member_profile_screen.dart';

/// Staff Portal > Reports. Owners and managers review posts and comments
/// that members reported, then either dismiss the report or remove the
/// content. To remove the person as well, use Staff Portal > Members.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final ModerationService _moderationService = ModerationService();
  late final Stream<List<ContentReport>> _reports;

  /// Reports with an action in progress (shows a spinner on that card)
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    // Created once here, not in build(), so the list doesn't reload on every rebuild
    _reports = _moderationService.openReportsStream();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? AppColors.error : null),
    );
  }

  Future<void> _run(ContentReport report, Future<String?> Function() action, String done) async {
    setState(() => _busy.add(report.id));
    final error = await action();
    if (!mounted) return;
    setState(() => _busy.remove(report.id));
    _showMessage(error ?? done, isError: error != null);
  }

  Future<void> _dismiss(ContentReport report) {
    return _run(report, () => _moderationService.dismiss(report), 'Report dismissed');
  }

  Future<void> _remove(ContentReport report) async {
    final what = report.isComment ? 'comment' : 'post';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove this $what?'),
        content: Text(
          'The $what by ${report.contentAuthorName} will be deleted for everyone. '
              'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await _run(report, () => _moderationService.removeContent(report), 'The $what was removed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: context.colors.appBar,
      ),
      body: StreamBuilder<List<ContentReport>>(
        stream: _reports,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load reports. Only owners and managers can review them.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                  const SizedBox(height: 12),
                  Text('No reports to review',
                      style: TextStyle(color: context.colors.textMuted)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reports.length,
            itemBuilder: (context, i) => _reportCard(reports[i]),
          );
        },
      ),
    );
  }

  Widget _reportCard(ContentReport report) {
    final textTheme = Theme.of(context).textTheme;
    final what = report.isComment ? 'Comment' : 'Post';
    final when = report.createdAt == null
        ? ''
        : ' · ${DateFormat('MMM d, h:mm a').format(report.createdAt!)}';
    final isBusy = _busy.contains(report.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reason
            Row(
              children: [
                const Icon(Icons.flag, size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    report.reason,
                    style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Reported by ${report.reportedByName}$when',
              style: textTheme.bodySmall,
            ),
            if (report.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('"${report.details}"'),
            ],
            const SizedBox(height: 12),

            // The reported content, as it was when reported
            InkWell(
              onTap: () => MemberProfileScreen.open(context, report.contentAuthorId),
              child: Text(
                '$what by ${report.contentAuthorName}',
                style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.colors.surfaceHigh,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                report.contentText.isEmpty ? '(no text)' : report.contentText,
              ),
            ),
            if (report.mediaCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Includes ${report.mediaCount} photo or video '
                    '${report.mediaCount == 1 ? 'file' : 'files'}. '
                    'Look at the post in the feed before deciding.',
                style: textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),

            // Actions
            if (isBusy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _dismiss(report),
                    child: const Text('Dismiss'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => _remove(report),
                    child: Text(
                      'Remove ${what.toLowerCase()}',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}