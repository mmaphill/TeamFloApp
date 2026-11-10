import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../models/app_roles.dart';
import '../services/gym_service.dart';
import '../services/membership_service.dart';
import 'member_profile_screen.dart';

/// Staff Portal > Members. Every staff role can see who's in the gym.
/// Owners and managers can also remove people (rank rules in AppRoles.canRemove,
/// enforced by the removeFromGym Cloud Function).
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final MembershipService _membershipService = MembershipService();
  final TextEditingController _searchController = TextEditingController();
  late final Stream<List<GymMember>> _members;
  final String? _myUid = FirebaseAuth.instance.currentUser?.uid;
  String _search = '';

  /// Members currently being removed (shows a spinner on that row)
  final Set<String> _removing = {};

  @override
  void initState() {
    super.initState();
    // Created once here, not in build(), so the list doesn't reload on every rebuild
    _members = _membershipService.membersStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmRemove(GymMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text(
          'They will lose access to the app right away. Their posts and '
              'journal entries stay.\n\n'
              'To let them back in later, use "Invite again" under Invites > Revoked, '
              'or invite their email again.',
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

    setState(() => _removing.add(member.uid));
    final error = await _membershipService.removeFromGym(member.uid);
    if (!mounted) return;
    setState(() => _removing.remove(member.uid));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '${member.name} was removed from the gym'),
        backgroundColor: error != null ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myRole = context.watch<GymService>().role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Members'),
        backgroundColor: context.colors.appBar,
      ),
      body: StreamBuilder<List<GymMember>>(
        stream: _members,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load members.'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final query = _search.trim().toLowerCase();
          final members = query.isEmpty
              ? all
              : all.where((m) =>
          m.name.toLowerCase().contains(query) ||
              m.email.toLowerCase().contains(query)).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search ${all.length} members',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: members.isEmpty
                    ? Center(
                  child: Text('No members found',
                      style: TextStyle(color: context.colors.textMuted)),
                )
                    : ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, i) => _memberTile(members[i], myRole),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _memberTile(GymMember member, String myRole) {
    final isMe = member.uid == _myUid;
    final canRemove = !isMe && AppRoles.canRemove(myRole, member.role);
    final isRemoving = _removing.contains(member.uid);

    return ListTile(
      onTap: () => MemberProfileScreen.open(context, member.uid),
      leading: CircleAvatar(
        backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
        child: member.photoUrl == null ? const Icon(Icons.person) : null,
      ),
      title: Text(isMe ? '${member.name} (you)' : member.name),
      subtitle: Text(
        member.role == AppRoles.member
            ? member.email
            : '${AppRoles.label(member.role)} · ${member.email}',
        overflow: TextOverflow.ellipsis,
      ),
      trailing: isRemoving
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : canRemove
          ? PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'remove') _confirmRemove(member);
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, size: 20, color: AppColors.error),
                SizedBox(width: 8),
                Text('Remove from gym', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      )
          : null,
    );
  }
}