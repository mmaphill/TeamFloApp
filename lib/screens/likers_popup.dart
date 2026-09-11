import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'all_likers_sheet.dart';

class LikersPopup extends StatefulWidget {
  final List<String> likedBy;

  const LikersPopup({
    super.key,
    required this.likedBy,
  });

  @override
  State<LikersPopup> createState() => _LikersPopupState();
}

class _LikersPopupState extends State<LikersPopup> {
  final ChatService _chatService = ChatService();
  late Future<List<String>> _userNamesFuture;

  @override
  void initState() {
    super.initState();
    // Get up to 3 most recent likers (last 3 in the list)
    final recentLikers = widget.likedBy.length > 3
        ? widget.likedBy.sublist(widget.likedBy.length - 3)
        : widget.likedBy;
    _userNamesFuture = _fetchUserNames(recentLikers);
  }

  Future<List<String>> _fetchUserNames(List<String> userIds) async {
    List<String> names = [];
    for (String userId in userIds) {
      try {
        final userName = await _chatService.getUserName(userId);
        names.add(userName);
      } catch (e) {
        names.add('Unknown User');
      }
    }
    return names;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _userNamesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return AlertDialog(
            content: SizedBox(
              width: 150,
              height: 50,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return AlertDialog(
            title: const Text('Likes'),
            content: const Text('No likes yet'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        }

        List<String> names = snapshot.data!;
        bool hasMore = widget.likedBy.length > 3;

        return AlertDialog(
          title: const Text('Likes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...names.map((name) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(name),
              )),
              if (hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _showAllLikers(context);
                    },
                    child: Text(
                      'See all ${widget.likedBy.length} likes',
                      style: const TextStyle(
                        color: Color(0xFFEA2327),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAllLikers(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => AllLikersSheet(likedBy: widget.likedBy),
      isScrollControlled: true,
    );
  }
}