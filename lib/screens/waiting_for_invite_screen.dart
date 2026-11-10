import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/auth_service.dart';

/// Shown to a signed-in account that isn't part of any gym yet.
///
/// The app is invite-only: a gym's staff invite an email, then the person
/// signs up with it. If someone signs up first, they land here. When staff
/// invite their email, a Cloud Function adds them to the gym and this
/// screen opens into the app by itself (GymService is listening).
///
/// Sign out and Delete account stay available (Apple requires account
/// deletion inside the app).
class WaitingForInviteScreen extends StatefulWidget {
  const WaitingForInviteScreen({super.key});

  @override
  State<WaitingForInviteScreen> createState() => _WaitingForInviteScreenState();
}

class _WaitingForInviteScreenState extends State<WaitingForInviteScreen> {
  final AuthService _authService = AuthService();
  bool _deleting = false;

  Future<void> _deleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text('This permanently deletes your account. This cannot be undone.'),
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

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _deleting = true);
    final error = await _authService.deleteAccount(uid);
    if (!mounted) return;
    setState(() => _deleting = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.contains('requires-recent-login')
              ? 'For security, please sign out, sign back in, and try again.'
              : 'Could not delete your account: $error'),
          backgroundColor: AppColors.error,
        ),
      );
    }
    // On success, Firebase signs the user out and the app returns to login.
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mark_email_unread_outlined, size: 64, color: context.colors.textMuted),
                const SizedBox(height: 16),
                Text(
                  'Waiting for an invite',
                  style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This app is for members of a gym. Ask your gym\'s front desk '
                      'or an instructor to invite:',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                SelectableText(
                  email,
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Once they do, this screen will open into the app on its own.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.textMuted),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _deleting ? null : () => _authService.logout(),
                    child: const Text('Sign out'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _deleting ? null : _deleteAccount,
                  child: _deleting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Delete account', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}