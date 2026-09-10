import 'package:flutter/material.dart';
import '../services/chat_service.dart';

class AllLikersSheet extends StatefulWidget {
  final List<String> likedBy;

  const AllLikersSheet({
    super.key,
    required this.likedBy,
  });

  @override
  State<AllLikersSheet> createState() => _AllLikersSheetState();
}

class _AllLikersSheetState extends State<AllLikersSheet> {
  final ChatService _chatService = ChatService();
  late Future<List<String>> _userNamesFuture;

  @override
  void initState() {
    super.initState();
    _userNamesFuture = _fetchAllUserNames();
  }

  Future<List<String>> _fetchAllUserNames() async {
    List<String> names = [];
    for (String userId in widget.likedBy.reversed) {
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
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Liked by ${widget.likedBy.length}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Divider(),

          // Likers List
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _userNamesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No likes yet'));
                }

                List<String> names = snapshot.data!;
                return ListView.builder(
                  controller: scrollController,
                  itemCount: names.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(names[index]),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}