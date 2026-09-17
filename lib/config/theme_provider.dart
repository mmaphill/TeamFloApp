import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ThemeProvider extends ChangeNotifier {
  // Start with dark mode as default
  ThemeMode _themeMode = ThemeMode.dark;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Initialize theme from Firestore on app launch
  Future<void> loadSavedTheme() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final savedTheme = data?['themeMode'] as String? ?? 'dark';

        if (savedTheme == 'light') {
          _themeMode = ThemeMode.light;
        } else {
          _themeMode = ThemeMode.dark;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error loading theme: $e');
      _themeMode = ThemeMode.dark; // Fallback to dark
    }
  }

  /// Toggle between dark and light mode
  Future<void> toggleTheme() async {
    try {
      _themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
      notifyListeners();

      // Persist to Firestore
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'themeMode': isDarkMode ? 'dark' : 'light',
        });
      }
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }

  /// Set specific theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      _themeMode = mode;
      notifyListeners();

      // Persist to Firestore
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'themeMode': mode == ThemeMode.dark ? 'dark' : 'light',
        });
      }
    } catch (e) {
      print('Error saving theme preference: $e');
    }
  }
}