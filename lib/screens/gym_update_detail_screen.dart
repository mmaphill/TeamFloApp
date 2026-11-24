import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../models/app_roles.dart';
import '../models/gym_update_model.dart';
import '../services/gym_service.dart';
import '../services/gym_update_service.dart';
import '../widgets/gym_update_card.dart';

/// GYM UPDATES: one update, fully open. Opened by tapping a
/// "new gym update" notification.
///
/// Waits for the gym to load first: when the app is started by the
/// notification, the gym isn't known yet, and loading the update too early
/// would look in the wrong place.
class GymUpdateDetailScreen extends StatefulWidget {
  final String updateId;

  const GymUpdateDetailScreen({super.key, required this.updateId});

  @override
  State<GymUpdateDetailScreen> createState() => _GymUpdateDetailScreenState();
}

class _GymUpdateDetailScreenState extends State<GymUpdateDetailScreen> {
  Future<GymUpdate?>? _future; // started once the gym has loaded

  @override
  Widget build(BuildContext context) {
    final gym = context.watch<GymService>();
    if (gym.isLoaded && _future == null) {
      _future = GymUpdateService().getUpdate(widget.updateId);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Update'),
        backgroundColor: context.colors.appBar,
      ),
      body: _future == null
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<GymUpdate?>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _message('Could not load this update.\n${snapshot.error}');
          }
          final update = snapshot.data;
          if (update == null) {
            return _message('This update was removed.');
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              GymUpdateCard(
                update: update,
                startExpanded: true,
                canManage: AppRoles.canSendAnnouncements(gym.role),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _message(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
