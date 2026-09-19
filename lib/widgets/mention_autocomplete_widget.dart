import 'package:flutter/material.dart';
import '../services/mention_service.dart';

class MentionAutocomplete extends StatefulWidget {
  final TextEditingController textController;
  final Function(String userId, String userName) onMentionSelected;
  final ValueChanged<bool>? onShowSuggestions;

  const MentionAutocomplete({
    super.key,
    required this.textController,
    required this.onMentionSelected,
    this.onShowSuggestions,
  });

  @override
  State<MentionAutocomplete> createState() => _MentionAutocompleteState();
}

class _MentionAutocompleteState extends State<MentionAutocomplete> {
  final MentionService _mentionService = MentionService();
  List<Map<String, dynamic>> _suggestions = [];
  bool _showSuggestions = false;
  String _currentQuery = '';
  int _mentionStartIndex = -1;

  @override
  void initState() {
    super.initState();
    widget.textController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final text = widget.textController.text;
    final cursorPos = widget.textController.selection.base.offset;

    int atIndex = text.lastIndexOf('@', cursorPos - 1);

    if (atIndex != -1 && atIndex < cursorPos) {
      String textAfterAt = text.substring(atIndex + 1, cursorPos);

      if (!textAfterAt.contains(' ')) {
        _mentionStartIndex = atIndex;
        _currentQuery = textAfterAt;
        _searchUsers(_currentQuery);
        _setSuggestionsVisibility(true);
        return;
      }
    }

    _setSuggestionsVisibility(false);
    _suggestions.clear();
  }

  void _setSuggestionsVisibility(bool visible) {
    if (_showSuggestions != visible) {
      setState(() {
        _showSuggestions = visible;
      });
      widget.onShowSuggestions?.call(visible);
    }
  }

  Future<void> _searchUsers(String query) async {
    final results = await _mentionService.searchUsersByName(query);
    setState(() {
      _suggestions = results;
    });
  }

  void _insertMention(String userId, String userName) {
    final text = widget.textController.text;
    final cursorPos = widget.textController.selection.base.offset;

    String beforeMention = text.substring(0, _mentionStartIndex);
    String afterMention = text.substring(cursorPos);
    String newText = '$beforeMention@$userName $afterMention';

    widget.textController.text = newText;
    widget.textController.selection = TextSelection.fromPosition(
      TextPosition(offset: beforeMention.length + userName.length + 2),
    );

    widget.onMentionSelected(userId, userName);

    _setSuggestionsVisibility(false);
    _suggestions.clear();
  }

  @override
  void dispose() {
    widget.textController.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_showSuggestions || _suggestions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Determine positioning: try right, fallback to left
    final screenWidth = MediaQuery.of(context).size.width;
    final dropdownWidth = 150.0;
    final padding = 16.0;

    bool alignRight = (screenWidth - padding - dropdownWidth) > padding;

    return Align(
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          right: alignRight ? padding : 0,
          left: !alignRight ? padding : 0,
        ),
        child: Container(
          width: dropdownWidth,
          constraints: const BoxConstraints(
            maxHeight: 200,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF4A4A4A), // Gray background
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            itemCount: _suggestions.length,
            itemBuilder: (context, index) {
              final user = _suggestions[index];
              final isFirst = index == 0;
              final isLast = index == _suggestions.length - 1;

              return GestureDetector(
                onTap: () => _insertMention(user['uid'], user['name']),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(isFirst ? 8 : 0),
                      topRight: Radius.circular(isFirst ? 8 : 0),
                      bottomLeft: Radius.circular(isLast ? 8 : 0),
                      bottomRight: Radius.circular(isLast ? 8 : 0),
                    ),
                    color: const Color(0xFF4A4A4A),
                  ),
                  child: MouseRegion(
                    onEnter: (_) {
                      // Optional: highlight on hover on web/desktop
                    },
                    child: Text(
                      user['name'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}