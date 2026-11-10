import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../services/invite_service.dart';

/// Staff Portal > Invites. Owners, managers, instructors and front desk
/// invite people to the gym by email and can revoke or re-send invites.
class InvitesScreen extends StatefulWidget {
  const InvitesScreen({super.key});

  @override
  State<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends State<InvitesScreen> {
  final InviteService _inviteService = InviteService();
  final TextEditingController _emailController = TextEditingController();
  late final Stream<List<Invite>> _invites;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Created once here, not in build(), so the list doesn't reload on every rebuild
    _invites = _inviteService.invitesStream();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _showMessage(String text, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text;
    if (email.trim().isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final error = await _inviteService.invite(email);
    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      _showMessage(error, isError: true);
    } else {
      _emailController.clear();
      _showMessage(
          'Invite emailed to ${InviteService.normalize(email)}. They must sign up with this email.');
    }
  }

  Future<void> _revoke(Invite invite) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Revoke invite?'),
        content: Text('${invite.email} will not be able to join with this invite.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final error = await _inviteService.revoke(invite.email);
    _showMessage(error ?? 'Invite revoked', isError: error != null);
  }

  Future<void> _resend(Invite invite) async {
    final error = await _inviteService.resend(invite.email);
    _showMessage(error ?? 'Invite emailed again', isError: error != null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invites'),
        backgroundColor: context.colors.appBar,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _inviteForm(),
          const SizedBox(height: 24),
          StreamBuilder<List<Invite>>(
            stream: _invites,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Could not load invites.');
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final invites = snapshot.data!;
              final pending = invites.where((i) => i.status == InviteStatus.pending).toList();
              final joined = invites.where((i) => i.status == InviteStatus.used).toList();
              final revoked = invites.where((i) => i.status == InviteStatus.revoked).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader('Pending (${pending.length})'),
                  if (pending.isEmpty) _emptyText('No pending invites'),
                  ...pending.map(_pendingTile),
                  const SizedBox(height: 20),
                  _sectionHeader('Joined (${joined.length})'),
                  if (joined.isEmpty) _emptyText('No one has joined with an invite yet'),
                  ...joined.map(_joinedTile),
                  if (revoked.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionHeader('Revoked (${revoked.length})'),
                    ...revoked.map(_revokedTile),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------- Widgets ----------

  Widget _inviteForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invite a new member',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Only people you invite can use the app. We email them the download '
                'links; they must sign up with this exact email.',
            style: TextStyle(color: context.colors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendInvite(),
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendInvite,
              icon: _sending
                  ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Icon(Icons.person_add),
              label: const Text('Invite'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: TextStyle(color: context.colors.textMuted)),
    );
  }

  String _date(DateTime? d) => d == null ? '' : DateFormat('MMM d, yyyy').format(d);

  Widget _pendingTile(Invite invite) {
    final by = invite.invitedByName != null ? ' by ${invite.invitedByName}' : '';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.mail_outline, color: AppColors.warning),
      title: Text(invite.email),
      subtitle: Text('Invited ${_date(invite.createdAt)}$by'),
      trailing: TextButton(
        onPressed: () => _revoke(invite),
        child: const Text('Revoke', style: TextStyle(color: AppColors.error)),
      ),
    );
  }

  Widget _joinedTile(Invite invite) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.check_circle, color: AppColors.success),
      title: Text(invite.email),
      subtitle: Text('Joined ${_date(invite.usedAt)}'),
    );
  }

  Widget _revokedTile(Invite invite) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.block, color: context.colors.textMuted),
      title: Text(invite.email),
      subtitle: const Text('Revoked'),
      trailing: TextButton(
        onPressed: () => _resend(invite),
        child: const Text('Invite again'),
      ),
    );
  }
}