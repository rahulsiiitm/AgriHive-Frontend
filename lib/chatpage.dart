// chat_page.dart - Optimized with on-demand chat loading
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:my_app/chat_history_sidebar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatPage extends StatefulWidget {
  final String userId;

  const ChatPage({super.key, required this.userId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ImagePicker _picker = ImagePicker();
  final List<ChatMessage> messages = [];
  SharedPreferences? _prefs;

  // Cache keys for current chat only
  static const String _currentChatMessagesKey = 'current_chat_messages_';
  static const String _currentChatIdKey = 'current_chatId_';
  static const String _cacheTimestampKey = 'cache_timestamp_';
  static const Duration _cacheExpiry = Duration(hours: 24);

  late final ChatUser user = ChatUser(id: widget.userId, firstName: "You");

  final ChatUser bot = ChatUser(
    id: "bot",
    firstName: "AgriBot",
    profileImage: "assets/images/app_icon.png",
  );

  bool isLoading = false;
  bool isSidebarVisible = false;
  bool isLoadingChat = false;
  String? currentChatId;

  @override
  void initState() {
    super.initState();
    _initializeCache();
  }

  Future<void> _initializeCache() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadCurrentChatFromCache();

    if (messages.isEmpty) {
      _addWelcomeMessage();
    }
  }

  Future<void> _loadCurrentChatFromCache() async {
    if (_prefs == null) return;

    try {
      final cacheTimestamp =
          _prefs!.getInt('$_cacheTimestampKey${widget.userId}') ?? 0;
      final isExpired =
          DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(cacheTimestamp),
          ) >
          _cacheExpiry;

      if (isExpired) {
        await _clearCurrentChatCache();
        return;
      }

      // Load current chat ID
      currentChatId = _prefs!.getString('$_currentChatIdKey${widget.userId}');

      // Load only current chat messages
      if (currentChatId != null) {
        final cachedMessagesJson = _prefs!.getString(
          '$_currentChatMessagesKey${widget.userId}_$currentChatId',
        );
        if (cachedMessagesJson != null) {
          final messagesList = json.decode(cachedMessagesJson) as List;
          final cachedMessages =
              messagesList
                  .map((msgJson) => _deserializeChatMessage(msgJson))
                  .toList();

          setState(() {
            messages.clear();
            messages.addAll(cachedMessages);
          });
        }
      }
    } catch (e) {
      await _clearCurrentChatCache();
    }
  }

  Future<void> _saveCurrentChatToCache() async {
    if (_prefs == null || currentChatId == null) return;

    try {
      final messagesJson =
          messages.map((msg) => _serializeChatMessage(msg)).toList();
      await _prefs!.setString(
        '$_currentChatMessagesKey${widget.userId}_$currentChatId',
        json.encode(messagesJson),
      );
      await _prefs!.setString(
        '$_currentChatIdKey${widget.userId}',
        currentChatId!,
      );
      await _prefs!.setInt(
        '$_cacheTimestampKey${widget.userId}',
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Silently handle cache errors
    }
  }

  Future<void> _clearCurrentChatCache() async {
    if (_prefs == null) return;

    // Clear current chat cache
    if (currentChatId != null) {
      await _prefs!.remove(
        '$_currentChatMessagesKey${widget.userId}_$currentChatId',
      );
    }
    await _prefs!.remove('$_currentChatIdKey${widget.userId}');
    await _prefs!.remove('$_cacheTimestampKey${widget.userId}');
  }

  // Load specific chat from backend
  Future<void> _loadChatFromBackend(String chatId) async {
    if (isLoadingChat) return;

    setState(() {
      isLoadingChat = true;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showSnackBar("No internet connection");
        return;
      }

      final response = await http
          .get(
            Uri.parse(
              "https://agrihive-server91.onrender.com/getChat?chatId=$chatId&userId=${widget.userId}",
            ),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Save current chat before switching
        if (currentChatId != null &&
            currentChatId != chatId &&
            messages.isNotEmpty) {
          await _saveCurrentChatToCache();
        }

        // Clear current messages and load new chat
        setState(() {
          messages.clear();
          currentChatId = chatId;
        });

        // Parse and load messages from backend response
        if (data['messages'] != null) {
          final chatMessages = <ChatMessage>[];

          for (var messageData in data['messages']) {
            final isBot =
                messageData['sender'] == 'bot' ||
                messageData['sender'] == 'assistant';
            final chatUser = isBot ? bot : user;

            final message = ChatMessage(
              user: chatUser,
              text: messageData['content'] ?? messageData['message'] ?? '',
              createdAt:
                  messageData['timestamp'] != null
                      ? DateTime.parse(messageData['timestamp'])
                      : DateTime.now(),
            );

            chatMessages.add(message);
          }

          setState(() {
            // Add messages in reverse order (newest first for DashChat)
            messages.addAll(chatMessages.reversed);
          });
        }

        // Cache the loaded chat
        await _saveCurrentChatToCache();
      } else {
        _showSnackBar("Failed to load chat: ${response.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error loading chat: ${e.toString()}");
    } finally {
      setState(() {
        isLoadingChat = false;
      });
    }
  }

  Map<String, dynamic> _serializeChatMessage(ChatMessage message) {
    return {
      'userId': message.user.id,
      'userFirstName': message.user.firstName ?? '',
      'userProfileImage': message.user.profileImage ?? '',
      'text': message.text,
      'createdAt': message.createdAt.millisecondsSinceEpoch,
      'medias':
          message.medias
              ?.map(
                (media) => {
                  'url': media.url,
                  'fileName': media.fileName,
                  'type': media.type.toString(),
                },
              )
              .toList(),
    };
  }

  ChatMessage _deserializeChatMessage(Map<String, dynamic> json) {
    final user = ChatUser(
      id: json['userId'],
      firstName: json['userFirstName'],
      profileImage:
          json['userProfileImage'].isEmpty ? null : json['userProfileImage'],
    );

    List<ChatMedia>? medias;
    if (json['medias'] != null) {
      medias =
          (json['medias'] as List)
              .map(
                (mediaJson) => ChatMedia(
                  url: mediaJson['url'],
                  fileName: mediaJson['fileName'],
                  type: _parseMediaType(mediaJson['type']),
                ),
              )
              .toList();
    }

    return ChatMessage(
      user: user,
      text: json['text'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt']),
      medias: medias,
    );
  }

  MediaType _parseMediaType(String typeString) {
    switch (typeString) {
      case 'MediaType.image':
        return MediaType.image;
      case 'MediaType.video':
        return MediaType.video;
      case 'MediaType.file':
        return MediaType.file;
      default:
        return MediaType.image;
    }
  }

  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      user: bot,
      createdAt: DateTime.now(),
      text: """🌱 **Welcome to AgriChat!** 

I'm your agricultural assistant, here to help you with:

• **Plant disease identification** - Send me photos of your plants
• **Crop management advice** - Ask about farming techniques
• **Agricultural guidance** - Get answers to your farming questions

*How can I assist you today?* 📸✨""",
    );

    setState(() {
      messages.insert(0, welcomeMessage);
    });

    // Don't save welcome message to cache for new chats
  }

  Widget _buildFormattedText(String text, Color textColor) {
    final spans = <TextSpan>[];
    final boldRegex = RegExp(r'\*\*(.*?)\*\*');
    final italicRegex = RegExp(r'\*(.*?)\*');

    final allMatches = <MapEntry<int, String>>[];

    for (final match in boldRegex.allMatches(text)) {
      allMatches.add(MapEntry(match.start, 'bold:${match.group(1)}'));
    }

    for (final match in italicRegex.allMatches(text)) {
      bool isPartOfBold = boldRegex
          .allMatches(text)
          .any(
            (boldMatch) =>
                match.start >= boldMatch.start && match.end <= boldMatch.end,
          );

      if (!isPartOfBold) {
        allMatches.add(MapEntry(match.start, 'italic:${match.group(1)}'));
      }
    }

    allMatches.sort((a, b) => a.key.compareTo(b.key));

    int currentIndex = 0;
    for (final match in allMatches) {
      if (match.key > currentIndex) {
        final normalText = text.substring(currentIndex, match.key);
        if (normalText.isNotEmpty) {
          spans.add(
            TextSpan(
              text: normalText,
              style: TextStyle(
                fontFamily: 'lufga',
                fontSize: 14,
                height: 1.4,
                color: textColor,
              ),
            ),
          );
        }
      }

      final parts = match.value.split(':');
      final type = parts[0];
      final content = parts[1];

      if (type == 'bold') {
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              fontFamily: 'lufga',
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        );
        currentIndex = match.key + content.length + 4;
      } else if (type == 'italic') {
        spans.add(
          TextSpan(
            text: content,
            style: TextStyle(
              fontFamily: 'lufga',
              fontSize: 14,
              height: 1.4,
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
          ),
        );
        currentIndex = match.key + content.length + 2;
      }
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: TextStyle(
            fontFamily: 'lufga',
            fontSize: 14,
            height: 1.4,
            color: textColor,
          ),
        ),
      );
    }

    if (spans.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontFamily: 'lufga',
          fontSize: 14,
          height: 1.4,
          color: textColor,
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  String _formatGeminiResponse(String label, String info) {
    return """🎯 **Prediction: ${label.toUpperCase()}**

📝 **Analysis:**
${info.replaceAll('. ', '.\n\n')}

💡 **Need more help?** *Feel free to ask questions about this plant!*""";
  }

  Future<void> sendMessage(ChatMessage message) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _showSnackBar("No internet connection");
      return;
    }

    setState(() {
      messages.insert(0, message);
      isLoading = true;
    });

    final botMsg = ChatMessage(
      user: bot,
      createdAt: DateTime.now(),
      text: "Thinking...",
    );

    setState(() => messages.insert(0, botMsg));

    try {
      final requestBody = {"message": message.text, "user_id": widget.userId};

      if (currentChatId != null) {
        requestBody["chatId"] = currentChatId!;
      }

      final res = await http
          .post(
            Uri.parse("https://agrihive-server91.onrender.com/chat"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data["is_new_chat"] == true || currentChatId == null) {
          currentChatId = data["chatId"];
        }

        setState(() {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: botMsg.createdAt,
            text: data["response"] ?? "No reply received",
          );
        });

        await _saveCurrentChatToCache();
      } else {
        setState(() {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: botMsg.createdAt,
            text: "Server error: ${res.statusCode}",
          );
        });
      }
    } catch (e) {
      setState(() {
        messages[0] = ChatMessage(
          user: bot,
          createdAt: botMsg.createdAt,
          text: "Connection error. Please check your server.",
        );
      });
      _showSnackBar("API Error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> sendImage() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        _showSnackBar("No internet connection");
        return;
      }

      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      if (!await file.exists()) {
        _showSnackBar("Selected image file not found");
        return;
      }

      if (await file.length() > 5 * 1024 * 1024) {
        _showSnackBar(
          "Image too large. Please select a smaller image (max 5MB)",
        );
        return;
      }

      final imgMsg = ChatMessage(
        user: user,
        createdAt: DateTime.now(),
        text: "🖼️ Image sent",
        medias: [
          ChatMedia(
            url: pickedFile.path,
            fileName: pickedFile.name,
            type: MediaType.image,
          ),
        ],
      );

      setState(() {
        messages.insert(0, imgMsg);
        isLoading = true;
      });

      final botMsg = ChatMessage(
        user: bot,
        createdAt: DateTime.now(),
        text: "🔍 Analyzing image...",
      );

      setState(() => messages.insert(0, botMsg));

      var request = http.MultipartRequest(
        'POST',
        Uri.parse("https://agrihive-server91.onrender.com/analyze_image"),
      );
      request.headers.addAll({'Accept': 'application/json'});
      request.fields['user_id'] = widget.userId;

      if (currentChatId != null) {
        request.fields['chatId'] = currentChatId!;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          pickedFile.path,
          filename: pickedFile.name,
          contentType: http_parser.MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final res = await http.Response.fromStream(streamedResponse);

      if (res.statusCode == 200) {
        try {
          final data = json.decode(res.body);

          if (data["is_new_chat"] == true || currentChatId == null) {
            currentChatId = data["chatId"];
          }

          final label = data["predicted_label"] ?? "Unknown";
          final info =
              data["gemini_explanation"] ?? "No explanation available.";

          setState(() {
            messages[0] = ChatMessage(
              user: bot,
              createdAt: botMsg.createdAt,
              text: _formatGeminiResponse(label, info),
            );
          });

          await _saveCurrentChatToCache();
        } catch (jsonError) {
          setState(() {
            messages[0] = ChatMessage(
              user: bot,
              createdAt: botMsg.createdAt,
              text: "❌ Invalid response format from server",
            );
          });
        }
      } else {
        setState(() {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: botMsg.createdAt,
            text: "❌ Server error: ${res.statusCode}\nResponse: ${res.body}",
          );
        });
      }
    } on TimeoutException {
      _updateBotMessage(
        "❌ Request timeout. Please try again with a smaller image.",
      );
      _showSnackBar("Request timeout - try a smaller image");
    } on SocketException {
      _updateBotMessage(
        "❌ Cannot connect to server. Please check if your server is running.",
      );
      _showSnackBar("Server connection failed");
    } on FormatException catch (e) {
      _updateBotMessage("❌ Invalid server response format.");
      _showSnackBar("Invalid response format: ${e.message}");
    } catch (e) {
      _updateBotMessage("❌ Error processing image. Please try again.");
      _showSnackBar("Image processing error: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _updateBotMessage(String text) {
    setState(() {
      if (messages.isNotEmpty && messages[0].user.id == bot.id) {
        messages[0] = ChatMessage(
          user: bot,
          createdAt: DateTime.now(),
          text: text,
        );
      }
    });
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'lufga',
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _toggleSidebar() {
    setState(() {
      isSidebarVisible = !isSidebarVisible;
    });
  }

  void _startNewChat() {
    setState(() {
      currentChatId = null;
      messages.clear();
      _addWelcomeMessage();
      isSidebarVisible = false;
    });
    _clearCurrentChatCache();
  }

  // Handle chat selection from sidebar
  void _onChatSelected(String chatId) {
    if (chatId == currentChatId) {
      // Same chat selected, just close sidebar
      setState(() {
        isSidebarVisible = false;
      });
      return;
    }

    // Load the selected chat
    _loadChatFromBackend(chatId);

    setState(() {
      isSidebarVisible = false;
    });
  }

  @override
  void dispose() {
    // Save current chat before disposing
    if (currentChatId != null && messages.isNotEmpty) {
      _saveCurrentChatToCache();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'lufga'),
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "🌱 AgriChat",
                style: TextStyle(
                  fontFamily: 'lufga',
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Text(
                "Your Smart Farming Assistant",
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Color(0xFF008000).withOpacity(0.3),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _startNewChat,
              tooltip: "New Chat",
            ),
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _toggleSidebar,
              tooltip: "Chat History",
            ),
            if (isLoading || isLoadingChat)
              const Padding(
                padding: EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/background.jpg'),
              fit: BoxFit.cover,
              opacity: 1.0,
            ),
          ),
          child: Stack(
            children: [
              // Show loading overlay when loading chat
              if (isLoadingChat)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Loading chat...',
                              style: TextStyle(fontFamily: 'lufga'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              else
                DashChat(
                  currentUser: user,
                  onSend: sendMessage,
                  messages: messages,
                  inputOptions: InputOptions(
                    inputDecoration: InputDecoration(
                      hintText: "Ask about agriculture...",
                      hintStyle: TextStyle(
                        fontSize: 14,
                        fontFamily: 'lufga',
                        color: Colors.grey.shade500,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide(
                          color: Colors.green.shade400,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Color.fromRGBO(255, 255, 255, 0.80),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    inputTextStyle: const TextStyle(
                      fontFamily: 'lufga',
                      fontWeight: FontWeight.w600,
                    ),
                    sendButtonBuilder:
                        (onSend) => Container(
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color.fromRGBO(0, 128, 0, 0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: onSend,
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    trailing: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(0, 128, 0, 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          onPressed:
                              (isLoading || isLoadingChat) ? null : sendImage,
                          icon: Icon(
                            Icons.photo_camera_rounded,
                            color:
                                (isLoading || isLoadingChat)
                                    ? Colors.grey.shade400
                                    : Colors.green.shade700,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  messageOptions: MessageOptions(
                    currentUserContainerColor: Color.fromARGB(227, 67, 160, 71),
                    containerColor: Colors.white.withOpacity(0.80),
                    textColor: Colors.grey.shade800,
                    currentUserTextColor: Colors.white,
                    messagePadding: const EdgeInsets.all(16),
                    borderRadius: 7,
                    messageTextBuilder: (
                      message,
                      previousMessage,
                      nextMessage,
                    ) {
                      final textColor =
                          message.user.id == user.id
                              ? Colors.white
                              : Colors.grey.shade800;
                      return _buildFormattedText(message.text, textColor);
                    },
                    showTime: true,
                  ),
                ),
              ChatHistorySidebarContainer(
                isVisible: isSidebarVisible,
                onClose: () => setState(() => isSidebarVisible = false),
                onChatSelected:
                    _onChatSelected, // Updated to use the new handler
                userId: widget.userId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
