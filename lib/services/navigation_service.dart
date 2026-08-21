import 'package:flutter/material.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static void goToHome(BuildContext context) {
    Navigator.pushNamed(context, '/home');
  }

  static void goToFeed(BuildContext context) {
    Navigator.pushNamed(context, '/feed');
  }

  static void goToCalendar(BuildContext context) {
    Navigator.pushNamed(context, '/calendar');
  }

  static void goToSchedule(BuildContext context) {
    Navigator.pushNamed(context, '/schedule');
  }

  static void goToProfile(BuildContext context) {
    Navigator.pushNamed(context, '/profile');
  }

  static void handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        goToHome(context);
        break;
      case 1:
        goToFeed(context);
        break;
      case 2:
        goToCalendar(context);
        break;
      case 3:
        goToSchedule(context);
        break;
      case 4:
        goToProfile(context);
        break;
    }
  }
}