import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../models/gym_update_model.dart';
import '../services/gym_update_service.dart';
import '../widgets/gym_update_card.dart';
import 'edit_gym_update_screen.dart';

/// GYM UPDATES: the staff view, opened from the Staff Portal.
/// "Current" is exactly what members see on Home. "Past events" are
/// dated updates whose day has passed; members no longer see them, and
/// staff can delete them or edit the date to bring one back.
class ManageUpdatesScreen extends StatefulWidget {
  const ManageUpdatesScreen({super.key});

  @override
  State<ManageUpdatesScreen> createState() => _ManageUpdatesScreenState();
}

class _ManageUpdatesScreenState extends State<ManageUpdatesScreen> {
  late final Stream<List<GymUpdate>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = GymUpdateService().updatesStream();
  }

  void _newUpdate() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditGymUpdateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Updates'),
        backgroundColor: context.colors.appBar,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newUpdate,
        backgroundColor: context.colors.primary,
        icon: const Icon(Icons.add, color: AppColors.onPrimary),
        label: const Text('New update', style: TextStyle(color: AppColors.onPrimary)),
      ),
      body: StreamBuilder<List<GymUpdate>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load updates.\n${snapshot.error}', textAlign: TextAlign.center),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final now = DateTime.now();
          final all = snapshot.data!;
          final current = GymUpdate.sortForFeed(all.where((u) => u.isVisibleOn(now)));
          final past = all.where((u) => !u.isVisibleOn(now)).toList()
            ..sort((a, b) => b.eventDate!.compareTo(a.eventDate!));

          if (all.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No updates yet.\nTap "New update" to post news or an event for your members.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView(
            // Room at the bottom so the button doesn't cover the last card
            padding: const EdgeInsets.only(top: 8, bottom: 96),
            children: [
              _header('Current (${current.length})', 'What members see on Home'),
              if (current.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Nothing showing on Home right now.'),
                ),
              ...current.map((u) => GymUpdateCard(key: ValueKey(u.id), update: u, canManage: true)),
              if (past.isNotEmpty) ...[
                const SizedBox(height: 16),
                _header('Past events (${past.length})', 'Hidden from members'),
                ...past.map((u) => Opacity(
                  opacity: 0.6,
                  child: GymUpdateCard(key: ValueKey(u.id), update: u, canManage: true),
                )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header(String title, String subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: context.colors.textMuted)),
        ],
      ),
    );
  }
}