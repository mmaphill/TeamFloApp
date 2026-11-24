import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/gym_update_model.dart';
import '../screens/edit_gym_update_screen.dart';
import '../services/attendance_stats_service.dart';
import '../services/gym_update_service.dart';
import 'fullscreen_image_viewer.dart';
import 'video_player_modal.dart';
import 'video_preview.dart';

/// GYM UPDATES: one update as a card. Picture or video on top, then the
/// heading, the event date (if any) and the description.
///
/// The description shows 3 lines with "Read more" when it's longer.
/// Staff who can post updates ([canManage]) get an Edit / Delete menu.
class GymUpdateCard extends StatefulWidget {
  final GymUpdate update;
  final bool canManage;
  final bool startExpanded;

  const GymUpdateCard({
    super.key,
    required this.update,
    this.canManage = false,
    this.startExpanded = false,
  });

  @override
  State<GymUpdateCard> createState() => _GymUpdateCardState();
}

class _GymUpdateCardState extends State<GymUpdateCard> {
  static const int _collapsedLines = 3;
  late bool _expanded = widget.startExpanded;

  @override
  Widget build(BuildContext context) {
    final u = widget.update;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (u.hasMedia) _media(u),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading + staff menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4, right: 10),
                        child: Text(
                          u.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    if (widget.canManage) _menu(u),
                  ],
                ),
                if (u.eventDate != null) ...[
                  const SizedBox(height: 6),
                  _eventChip(u.eventDate!),
                ],
                if (u.description.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _description(u.description),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Pieces ----------

  Widget _media(GymUpdate u) {
    if (u.isVideo) {
      return SizedBox(
        height: 220,
        width: double.infinity,
        child: VideoPreview(
          videoUrl: u.mediaUrl!,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VideoPlayerModal(videoUrl: u.mediaUrl!)),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        builder: (_) => FullscreenImageViewer(imageUrls: [u.mediaUrl!], initialIndex: 0),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          u.mediaUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: context.colors.surfaceHigh,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }

  Widget _eventChip(DateTime date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.primaryTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event, size: 16, color: context.colors.primary),
          const SizedBox(width: 6),
          Text(
            AttendanceStats.shortDate(date),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// 3 lines, then "Read more". The button only shows when the text is
  /// actually longer than 3 lines, measured at the card's real width.
  Widget _description(String text) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: style),
          maxLines: _collapsedLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final bool isLong = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: style,
              maxLines: _expanded ? null : _collapsedLines,
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
            if (isLong)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _expanded ? 'Show less' : 'Read more',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _menu(GymUpdate u) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditGymUpdateScreen(existing: u)),
          );
        } else if (value == 'delete') {
          _confirmDelete(u);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              SizedBox(width: 8),
              Text('Delete', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(GymUpdate u) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete update?'),
        content: Text('"${u.title}" will be removed for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await GymUpdateService().delete(u);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete: $e')),
      );
    }
  }
}
