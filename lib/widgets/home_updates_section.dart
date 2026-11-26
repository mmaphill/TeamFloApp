import 'dart:async';
import 'package:flutter/material.dart';
import '../models/app_roles.dart';
import '../models/gym_update_model.dart';
import '../services/gym_service.dart';
import '../services/gym_update_service.dart';
import '../utils/log.dart';
import 'gym_update_card.dart';

/// GYM UPDATES: the "Gym Updates" section on the Home screen.
/// Shows current updates only: events whose date has passed are hidden.
/// Shows nothing at all when there are no current updates.
class HomeUpdatesSection extends StatefulWidget {
  const HomeUpdatesSection({super.key});

  @override
  State<HomeUpdatesSection> createState() => _HomeUpdatesSectionState();
}

class _HomeUpdatesSectionState extends State<HomeUpdatesSection> {
  // Created once here, not in build(), so the list doesn't reload on
  // every rebuild of the Home screen.
  late final Stream<List<GymUpdate>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = GymUpdateService().updatesStream();
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = AppRoles.canSendAnnouncements(GymService.instance.role);

    return StreamBuilder<List<GymUpdate>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // Don't break the Home screen over this section
          log('Could not load gym updates: ${snapshot.error}');
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final now = DateTime.now();
        final current = GymUpdate.sortForFeed(
          snapshot.data!.where((u) => u.isVisibleOn(now)),
        );
        if (current.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Gym Updates',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...current.map((u) => GymUpdateCard(
              key: ValueKey(u.id),
              update: u,
              canManage: canManage,
            )),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}
