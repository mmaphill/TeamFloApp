import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/belt_rank_model.dart';
import '../models/user_model.dart';
import '../widgets/belt_rank_badge.dart';
import '../widgets/member_avatar.dart';

/// Read-only view of another member's profile.
///
/// Open it from anywhere with:
///   MemberProfileScreen.open(context, someUserId);
class MemberProfileScreen extends StatelessWidget {
  final String userId;

  const MemberProfileScreen({super.key, required this.userId});

  /// Convenience helper so callers don't need to build the route.
  static void open(BuildContext context, String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberProfileScreen(userId: userId),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Belt history, newest promotion first.
  List<BeltRank> _sortedBelts(UserModel user) {
    final belts = List<BeltRank>.from(user.beltRankHistory);
    belts.sort((a, b) => b.promotionDate.compareTo(a.promotionDate));
    return belts;
  }

  /// Age in whole years, accounting for whether the birthday has happened yet.
  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    final hadBirthday = now.month > dob.month ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// "2 yrs 3 mos", "5 mos", "Less than a month"
  String _timeSince(DateTime from) {
    final now = DateTime.now();
    int months = (now.year - from.year) * 12 + (now.month - from.month);
    if (now.day < from.day) months--;
    if (months < 1) return 'Less than a month';

    final years = months ~/ 12;
    final rem = months % 12;
    final parts = <String>[];
    if (years > 0) parts.add('$years ${years == 1 ? 'yr' : 'yrs'}');
    if (rem > 0) parts.add('$rem ${rem == 1 ? 'mo' : 'mos'}');
    return parts.join(' ');
  }

  /// "Blue" -> "Blue Belt"; leaves "Blue Belt" alone.
  String _beltLabel(String rank) {
    if (rank.isEmpty) return 'No belt listed';
    return rank.toLowerCase().contains('belt') ? rank : '$rank Belt';
  }

  Color _beltColor(String rank) {
    final r = rank.toLowerCase();
    if (r.contains('black')) return Colors.black;
    if (r.contains('brown')) return const Color(0xFF6D4C41);
    if (r.contains('purple')) return const Color(0xFF7B1FA2);
    if (r.contains('blue')) return const Color(0xFF1976D2);
    if (r.contains('green')) return const Color(0xFF388E3C);
    if (r.contains('orange')) return const Color(0xFFF57C00);
    if (r.contains('yellow')) return const Color(0xFFFBC02D);
    if (r.contains('grey') || r.contains('gray')) return Colors.grey;
    return Colors.white;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isOwnProfile = FirebaseAuth.instance.currentUser?.uid == userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Member Profile'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _Message(
              icon: Icons.error_outline,
              text: 'Could not load this profile.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data();
          if (!snapshot.data!.exists || data == null) {
            return const _Message(
              icon: Icons.person_off_outlined,
              text: 'This member could not be found.',
            );
          }

          final user = UserModel.fromMap(data);
          final belts = _sortedBelts(user);
          final currentBelt = belts.isNotEmpty ? belts.first : null;
          final currentRank = currentBelt?.rank ?? user.currentBelt ?? '';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (isOwnProfile) _ownProfileBanner(context),
              _header(context, user, currentRank),
              const SizedBox(height: 16),
              _currentBeltCard(context, currentBelt, currentRank),
              if (belts.length > 1) ...[
                const SizedBox(height: 16),
                _beltJourneyCard(context, belts),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _ownProfileBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, color: scheme.primary, size: 20),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('This is how other members see your profile.'),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, UserModel user, String currentRank) {
    final textTheme = Theme.of(context).textTheme;
    final chips = <Widget>[];

    if (user.showAge && user.dob != null) {
      chips.add(_InfoChip(
        icon: Icons.cake_outlined,
        label: 'Age ${_ageFrom(user.dob!)}',
      ));
    }
    chips.add(_InfoChip(
      icon: Icons.calendar_month_outlined,
      label: 'Member since ${DateFormat('MMM yyyy').format(user.createdAt)}',
    ));

    return Column(
      children: [
        MemberAvatar(user: user, radius: 56),
        const SizedBox(height: 12),
        Text(
          user.name.isNotEmpty ? user.name : 'Team Flo Member',
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        if (currentRank.isNotEmpty) ...[
          const SizedBox(height: 8),
          BeltRankBadge(beltRank: currentRank),
        ],
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  Widget _currentBeltCard(
      BuildContext context,
      BeltRank? currentBelt,
      String currentRank,
      ) {
    final textTheme = Theme.of(context).textTheme;

    return _SectionCard(
      title: 'Current Rank',
      child: Row(
        children: [
          _BeltDot(color: _beltColor(currentRank), size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _beltLabel(currentRank),
                  style: textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (currentBelt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Promoted ${DateFormat('MMM d, yyyy').format(currentBelt.promotionDate)}',
                  ),
                  Text(
                    '${_timeSince(currentBelt.promotionDate)} at this rank',
                    style: textTheme.bodySmall,
                  ),
                ] else
                  Text(
                    'No promotion date listed',
                    style: textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _beltJourneyCard(BuildContext context, List<BeltRank> belts) {
    return _SectionCard(
      title: 'Belt Journey',
      child: Column(
        children: belts.map((belt) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: _BeltDot(color: _beltColor(belt.rank), size: 24),
            title: Text(_beltLabel(belt.rank)),
            trailing: Text(
              DateFormat('MMM d, yyyy').format(belt.promotionDate),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small private widgets
// -----------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _BeltDot extends StatelessWidget {
  final Color color;
  final double size;

  const _BeltDot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // Outline so white and black belts are visible in both themes
        border: Border.all(color: Colors.grey, width: 1.5),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}