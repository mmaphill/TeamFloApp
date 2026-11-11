import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/moderation_service.dart';

/// Profile > Blocked members. Shows everyone this user has blocked and
/// lets them unblock. The list is private to the user.
class BlockedMembersScreen extends StatefulWidget {
  const BlockedMembersScreen({super.key});

  @override
  State<BlockedMembersScreen> createState() => _BlockedMembersScreenState();
}

class _BlockedMembersScreenState extends State<BlockedMembersScreen> {
  final ModerationService _moderationService = ModerationService();
  late final Stream<List<BlockedMember>> _blocked;

  @override
  void initState() {
    super.initState();
    // Created once here, not in build(), so the list doesn't reload on every rebuild
    _blocked = _moderationService.blockedMembersStream();
  }

  Future<void> _unblock(BlockedMember member) async {
    final error = await _moderationService.unblockUser(member.uid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${member.name} is unblocked'),
        backgroundColor: error != null ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked members'),
        backgroundColor: context.colors.appBar,
      ),
      body: StreamBuilder<List<BlockedMember>>(
        stream: _blocked,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load your blocked members.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final members = snapshot.data!;
          if (members.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'You haven\'t blocked anyone.\n\n'
                      'To block someone, tap the three dots on one of their posts or comments.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textMuted),
                ),
              ),
            );
          }

          return ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'You don\'t see posts or comments from these members, and you '
                      'aren\'t notified when they tag you.',
                  style: TextStyle(color: context.colors.textMuted),
                ),
              ),
              ...members.map(
                    (member) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(member.name),
                  trailing: TextButton(
                    onPressed: () => _unblock(member),
                    child: const Text('Unblock'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}