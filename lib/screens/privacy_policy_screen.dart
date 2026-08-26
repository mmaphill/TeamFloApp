import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../config/colors.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  final bool isFirstLogin;

  const PrivacyPolicyScreen({
    super.key,
    this.isFirstLogin = false,
  });

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _hasAgreed = false;

  Future<void> _acknowledgePolicy() async {
    setState(() => _isLoading = true);

    String uid = FirebaseAuth.instance.currentUser!.uid;
    String? error = await _authService.acknowledgePrivacyPolicy(uid);

    setState(() => _isLoading = false);

    if (error == null) {
      if (mounted) {
        if (widget.isFirstLogin) {
          // First login: go to home screen
          Navigator.of(context).pop();
        } else {
          // Regular access: go back
          Navigator.pop(context);
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.isFirstLogin, // Prevent back on first login
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy Policy'),
          backgroundColor: AppColors.dark,
          automaticallyImplyLeading: !widget.isFirstLogin, // Hide back on first login
        ),
        body: Column(
          children: [
            // Privacy Policy Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  '''TeamFloApp Privacy Policy

Last Updated: 08/26/2026
Effective Date: 08/26/2026

1. INTRODUCTION

TeamFloApp ("we," "us," "our," or "Company") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.

2. INFORMATION WE COLLECT

Account Registration:
- Full name
- Email address
- Password (encrypted)
- Belt rank/belt history
- Profile picture (optional)

Application Usage:
- Posts and comments you create
- Journal entries and training notes
- Class attendance records
- Photos and videos you upload
- Personal training reflections

3. HOW WE USE YOUR INFORMATION

- Account Management
- Community Features
- Training Tracking
- Class Management
- Service Improvement
- Support and Troubleshooting
- Safety and Fraud Prevention

4. INFORMATION SHARING

Public Information (visible to other app users):
- Your name and belt rank
- Posts you create
- Comments you make
- Profile picture (if uploaded)

Private Information (only for you and admins):
- Your email address
- Your password (admins do not have access to see your password, but may help in resetting)
- Your training journal entries
- Your personal statistics

5. DATA SECURITY

We implement industry-standard security:
- Encryption in transit and at rest
- Firebase security rules
- Password hashing
- HTTPS/TLS encrypted communication

6. DATA RETENTION

- Account Data: Retained while account is active
- Posts and Comments: Retained until deleted
- Journal Entries: Retained until deleted
- Uploaded Media: Retained while post/entry exists
- Deleted Accounts: Data deleted within 30 days

7. DATA DELETION & ACCOUNT DELETION

Users have the right to delete their account at any time:

How to Delete Your Account:
1. Go to Profile screen
2. Scroll to settings
3. Tap "Delete Account"
4. Confirm deletion

What Happens When You Delete:
- Your user profile is deleted
- All posts and comments are deleted
- All journal entries are deleted
- All uploaded photos/videos are deleted
- Your data is removed from Firebase within 24 hours

Note: Once deleted, your account cannot be recovered.

Data Retention After Deletion:
- Personal data: Deleted immediately
- Backup data: Deleted within 30 days
- Crash logs: May retain anonymized data for up to 90 days

8. DATA PORTABILITY

Users have the right to receive a copy of their data in a structured format.

To Request Your Data:
Email: [phill.w.nunez@gmail.com]
Subject: "Data Export Request"

Include:
- Your email address used for account
- Confirmation of identity

We will provide your data within 30 days in JSON format, including:
- Profile information
- All posts and comments
- Journal entries
- Training statistics
- Uploaded photos/videos (as links)

9. YOUR PRIVACY RIGHTS

Depending on your location, you have rights regarding your data:

For EU Residents (GDPR):
- Right to access your data
- Right to correct inaccurate data
- Right to delete your data ("right to be forgotten")
- Right to restrict processing
- Right to data portability
- Right to object to processing

For California Residents (CCPA):
- Right to know what data is collected
- Right to delete personal information
- Right to opt-out of data sales (we don't sell data)
- Right to non-discrimination for exercising your rights

To Exercise Your Rights:
Contact: [phill.w.nunez@gmail.com]
Response Time: 30-45 days

We will not discriminate against you for exercising these rights.

10. CONTACT US

If you have questions about this Privacy Policy:
Email: [phill.w.nunez@gmail.com]

By using TeamFloApp, you acknowledge that you have read, understood, and agree to be bound by this Privacy Policy.''',
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ),

            // I Agree Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _acknowledgePolicy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3A3A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white,
                      ),
                    ),
                  )
                      : const Text(
                    'I Agree',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}