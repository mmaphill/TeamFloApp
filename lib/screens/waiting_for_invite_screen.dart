import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../services/auth_service.dart';
import '../services/gym_service.dart';
import '../services/membership_service.dart';
import '../utils/log.dart';

/// Shown to a signed-in account that isn't part of any gym.
///
/// Step 1, EMAIL VERIFICATION: until the email is verified, ask the user
/// to click the link we sent. Checked again whenever the app comes back to
/// the front (they usually leave to open their email) and when they tap
/// "I've verified".
///
/// Step 2, INVITE: once verified, ask the gym to invite this email. If an
/// invite is already waiting, claimMyInvite adds them to the gym and this
/// screen opens into the app by itself (GymService is listening).
///
/// Also shown when an owner or manager removes the account from its gym.
/// Sign out and Delete account are always available (Apple requires
/// account deletion inside the app).
class WaitingForInviteScreen extends StatefulWidget {
  const WaitingForInviteScreen({super.key});

  @override
  State<WaitingForInviteScreen> createState() => _WaitingForInviteScreenState();
}

class _WaitingForInviteScreenState extends State<WaitingForInviteScreen>
    with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final MembershipService _membershipService = MembershipService();

  bool _verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
  bool _checking = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the email app: check again without the user tapping anything
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkStatus();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: isError ? AppColors.error : null),
    );
  }

  /// Reloads the account from Firebase (the verified flag only updates on
  /// reload), then tries to join with a pending invite.
  Future<void> _checkStatus({bool fromButton = false}) async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final verified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      if (!mounted) return;
      setState(() => _verified = verified);

      if (!verified) {
        if (fromButton) {
          _showMessage('Not verified yet. Click the link in the email, then try again.');
        }
        return;
      }

      final joined = await _membershipService.claimMyInvite();
      // If joined, GymService sees the new gym and this screen goes away.
      if (!joined && fromButton) {
        _showMessage('Email verified. Waiting for an invite from your gym.');
      }
    } catch (e) {
      log('Waiting screen check failed: $e');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    final error = await _authService.resendVerificationEmail();
    _showMessage(error ?? 'Verification email sent. Check your inbox and spam folder.',
        isError: error != null);
  }

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
      _showMessage(
        error.contains('requires-recent-login')
            ? 'For security, please sign out, sign back in, and try again.'
            : 'Could not delete your account: $error',
        isError: true,
      );
    }
    // On success, Firebase signs the user out and the app returns to login.
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'your email';
    final wasRemoved = context.watch<GymService>().wasRemoved;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_verified)
                  ..._verifyStep(email)
                else if (wasRemoved)
                  ..._removedStep()
                else
                  ..._inviteStep(email),
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

  // ---------- Step 1: verify email ----------

  List<Widget> _verifyStep(String email) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Icon(Icons.mark_email_read_outlined, size: 64, color: context.colors.textMuted),
      const SizedBox(height: 16),
      Text(
        'Verify your email',
        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text('We sent a verification link to:', textAlign: TextAlign.center),
      const SizedBox(height: 8),
      SelectableText(
        email,
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Text(
        'Click the link in that email, then come back here. '
            'Check your spam folder if you don\'t see it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.colors.textMuted),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _checking ? null : () => _checkStatus(fromButton: true),
          child: _checking
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text("I've verified"),
        ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: _resend,
        child: const Text('Resend email'),
      ),
    ];
  }

  // ---------- Step 2: wait for an invite ----------

  List<Widget> _inviteStep(String email) {
    final textTheme = Theme.of(context).textTheme;
    return [
      Icon(Icons.mark_email_unread_outlined, size: 64, color: context.colors.textMuted),
      const SizedBox(height: 16),
      Text(
        'Waiting for an invite',
        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text(
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
      const SizedBox(height: 16),
      TextButton(
        onPressed: _checking ? null : () => _checkStatus(fromButton: true),
        child: const Text('Check again'),
      ),
    ];
  }

  // ---------- Removed by the gym ----------

  List<Widget> _removedStep() {
    final textTheme = Theme.of(context).textTheme;
    return [
      Icon(Icons.lock_outline, size: 64, color: context.colors.textMuted),
      const SizedBox(height: 16),
      Text(
        'Your gym access has ended',
        style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      const Text(
        'Your gym has removed this account. If you think this is a mistake, '
            'contact your gym. If they invite you again, this screen will open '
            'into the app on its own.',
        textAlign: TextAlign.center,
      ),
    ];
  }
}