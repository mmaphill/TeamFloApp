import 'package:flutter/material.dart';
import '../config/colors.dart';

class BottomNavWrapper extends StatefulWidget {
  final Widget child;
  final int currentIndex;
  final Function(int) onNavTap;

  const BottomNavWrapper({
    super.key,
    required this.child,
    required this.currentIndex,
    required this.onNavTap,
  });

  @override
  State<BottomNavWrapper> createState() => _BottomNavWrapperState();
}

class _BottomNavWrapperState extends State<BottomNavWrapper> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: AppColors.primary,
        selectedItemColor: const Color(0xFFFFB2B3),
        unselectedItemColor: AppColors.light,

        type: BottomNavigationBarType.fixed,

        elevation: 8.0, // shadow depth
        iconSize: 24.0, // control the icon size

        // Label styling
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),

        // Show/Hide Labels
        showSelectedLabels: true,
        showUnselectedLabels: true,

        // Haptic Feedback on Tap
        enableFeedback: true,

        currentIndex: widget.currentIndex,
        onTap: widget.onNavTap,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Feed',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
      ),
    );
  }
}