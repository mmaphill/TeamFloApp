import 'package:flutter/material.dart';
import '../services/chat_service.dart';
import 'all_likers_sheet.dart';

class LikersPopup extends StatefulWidget {
  final List<String> likedBy;
  final Offset position;

  const LikersPopup({
    super.key,
    required this.likedBy,
    required this.position,
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
    return Material(
      color: Colors.transparent,
      child: FutureBuilder<List<String>>(
        future: _userNamesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Positioned(
              left: widget.position.dx,
              top: widget.position.dy,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SizedBox(
                  width: 100,
                  height: 50,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const SizedBox.shrink();
          }

          List<String> names = snapshot.data!;
          bool hasMore = widget.likedBy.length > 3;

          return Positioned(
            left: widget.position.dx - 80,
            top: widget.position.dy - 100,
            child: GestureDetector(
              onTap: () {}, // Prevent dismissing when tapping inside
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...names.map((name) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    )),
                    if (hasMore)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context); // Close popup
                            _showAllLikers(context);
                          },
                          child: Text(
                            'See all ${widget.likedBy.length} likes',
                            style: const TextStyle(
                              color: Color(0xFFEA2327),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
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