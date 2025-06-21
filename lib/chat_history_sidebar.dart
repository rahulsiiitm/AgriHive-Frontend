import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Data model for chat history items
class ChatHistoryItem {
  final String id;
  final String title;
  final String lastMessage;
  final DateTime createdAt;
  final int messageCount;

  ChatHistoryItem({
    required this.id,
    required this.title,
    required this.lastMessage,
    required this.createdAt,
    required this.messageCount,
  });
}

// API service function to fetch chat history
Future<List<ChatHistoryItem>> fetchChatHistory({
  required String userId, // Made required instead of optional with default
}) async {
  final url = Uri.parse(
    'https://agrihive-server91.onrender.com/getChats?userId=$userId',
  );

  final response = await http.get(url);

  if (kDebugMode) {
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
  }

  if (response.statusCode == 200) {
    final Map<String, dynamic> jsonData = json.decode(response.body);
    final List<dynamic> chatsJson = jsonData['chats'];

    return chatsJson.map((chatJson) {
      return ChatHistoryItem(
        id: chatJson['chatId'].toString(),
        title: chatJson['title'] ?? 'Untitled',
        lastMessage: chatJson['lastMessage'] ?? '',
        createdAt: DateTime.parse(chatJson['createdAt']),
        messageCount: chatJson['messageCount'] ?? 0,
      );
    }).toList();
  } else {
    throw Exception('Failed to load chat history');
  }
}

// API service function to delete all chats
Future<bool> deleteAllChatsApi({required String userId}) async {
  // Made required
  final url = Uri.parse(
    'https://agrihive-server91.onrender.com/deleteAllChats',
  );

  try {
    final response = await http.delete(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'userId': userId}),
    );

    if (kDebugMode) {
      print('Delete response status: ${response.statusCode}');
    }
    if (kDebugMode) {
      print('Delete response body: ${response.body}');
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> jsonData = json.decode(response.body);
      return jsonData['success'] ?? false;
    } else {
      return false;
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error deleting chats: $e');
    }
    return false;
  }
}

// Main sidebar widget (UI only)
class ChatHistorySidebar extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final Function(String chatId) onChatSelected;
  final VoidCallback onClearHistory;
  final List<ChatHistoryItem> chatHistory;
  final bool isLoading;
  final bool isDeleting;

  const ChatHistorySidebar({
    super.key,
    required this.isVisible,
    required this.onClose,
    required this.onChatSelected,
    required this.onClearHistory,
    required this.chatHistory,
    this.isLoading = false,
    this.isDeleting = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = screenWidth * 0.8 > 300 ? 300.0 : screenWidth * 0.8;

    return SizedBox.expand(
      child: Stack(
        children: [
          // Animated overlay background
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isVisible ? 1.0 : 0.0,
            child:
                isVisible
                    ? GestureDetector(
                      onTap: onClose,
                      child: Container(color: Color.fromRGBO(0, 0, 0, 0.5)),
                    )
                    : const SizedBox.shrink(),
          ),

          // Sliding sidebar
          AnimatedPositioned(
            top: 0,
            bottom: 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            right: isVisible ? 0 : -sidebarWidth,
            width: sidebarWidth,
            child: SafeArea(
              child: Material(
                elevation: 16,
                color: Colors.white,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(child: _buildHistoryList()),
                    _buildFooter(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.green.shade600,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.history, color: Color.fromARGB(255, 244, 239, 239)),
          const SizedBox(width: 8),
          const Text(
            "Chat History",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'lufga',
              fontSize: 13,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (chatHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 32,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "No chat history yet",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontFamily: 'lufga',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Start a conversation to see your chat history here",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontFamily: 'lufga',
                fontSize: 9,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: chatHistory.length,
      separatorBuilder:
          (context, index) => Divider(height: 1, color: Colors.grey.shade200),
      itemBuilder: (context, index) {
        final chat = chatHistory[index];
        return _buildChatHistoryTile(chat);
      },
    );
  }

  Widget _buildChatHistoryTile(ChatHistoryItem chat) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.chat_bubble_outline,
          color: Colors.green.shade600,
          size: 15,
        ),
      ),
      title: Text(
        chat.title,
        style: const TextStyle(
          fontFamily: 'lufga',
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Text(
            chat.lastMessage,
            style: TextStyle(
              fontFamily: 'lufga',
              color: Colors.grey.shade600,
              fontSize: 8,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.schedule, size: 8, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                _formatDate(chat.createdAt),
                style: TextStyle(
                  fontFamily: 'lufga',
                  color: Colors.grey.shade500,
                  fontSize: 8,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "${chat.messageCount}",
                  style: TextStyle(
                    fontFamily: 'lufga',
                    color: Colors.green.shade600,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () => onChatSelected(chat.id),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                // Close sidebar when starting new chat
                onClose();
              },
              icon: const Icon(Icons.add, size: 13),
              label: const Text(
                "New Chat",
                style: TextStyle(fontFamily: 'lufga', fontSize: 8),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed:
                isDeleting ? null : () => _showClearHistoryDialog(context),
            icon:
                isDeleting
                    ? SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.red.shade400,
                      ),
                    )
                    : Icon(
                      Icons.delete_outline,
                      color: Colors.red.shade400,
                      size: 15,
                    ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Clear Chat History',
            style: TextStyle(fontFamily: 'lufga', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to delete all chat history? This action cannot be undone.',
            style: TextStyle(fontFamily: 'lufga'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontFamily: 'lufga',
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onClearHistory();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Delete All',
                style: TextStyle(fontFamily: 'lufga'),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inHours < 1) {
      return "Just now";
    } else if (difference.inHours < 24) {
      return "${difference.inHours}h ago";
    } else if (difference.inDays == 1) {
      return "Yesterday";
    } else if (difference.inDays < 7) {
      return "${difference.inDays}d ago";
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return "${weeks}w ago";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }
}

// Container widget that manages state and API calls
class ChatHistorySidebarContainer extends StatefulWidget {
  final bool isVisible;
  final VoidCallback onClose;
  final Function(String chatId) onChatSelected;
  final String userId; // Add userId parameter

  const ChatHistorySidebarContainer({
    super.key,
    required this.isVisible,
    required this.onClose,
    required this.onChatSelected,
    required this.userId, // Make userId required
  });

  @override
  State<ChatHistorySidebarContainer> createState() =>
      _ChatHistorySidebarContainerState();
}

class _ChatHistorySidebarContainerState
    extends State<ChatHistorySidebarContainer> {
  List<ChatHistoryItem> chats = [];
  bool isLoading = true;
  bool isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  // Add this method to handle userId changes
  @override
  void didUpdateWidget(ChatHistorySidebarContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload chats if userId changed
    if (oldWidget.userId != widget.userId) {
      _loadChats();
    }
  }

  Future<void> _loadChats() async {
    setState(() {
      isLoading = true;
    });

    try {
      final fetchedChats = await fetchChatHistory(userId: widget.userId);
      setState(() {
        chats = fetchedChats;
        isLoading = false;
      });
    } catch (e) {
      // Handle error - for now just print
      if (kDebugMode) {
        print('Error fetching chats: $e');
      }
      setState(() {
        isLoading = false;
      });

      // You could also show a snackbar or error dialog here
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load chat history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearAllChats() async {
    setState(() {
      isDeleting = true;
    });

    try {
      final success = await deleteAllChatsApi(userId: widget.userId);

      if (success) {
        setState(() {
          chats.clear();
          isDeleting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chat history cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          isDeleting = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to clear chat history'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        isDeleting = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing chat history: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Method to refresh chat history (can be called from parent)
  Future<void> refreshChats() async {
    await _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    return ChatHistorySidebar(
      isVisible: widget.isVisible,
      onClose: widget.onClose,
      onChatSelected: widget.onChatSelected,
      onClearHistory: _clearAllChats,
      chatHistory: chats,
      isLoading: isLoading,
      isDeleting: isDeleting,
    );
  }
}
