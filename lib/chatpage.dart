import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dash_chat_2/dash_chat_2.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http_parser/http_parser.dart' as http_parser;
import 'package:my_app/chat_history_sidebar.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ImagePicker _picker = ImagePicker();
  final List<ChatMessage> messages = [];

  final ChatUser user = ChatUser(id: "user1", firstName: "You");
  final ChatUser bot = ChatUser(
    id: "bot",
    firstName: "AgriBot",
    profileImage: "assets/images/app_icon.png",
  );

  bool isLoading = false;
  bool isSidebarVisible = false;
  String? selectedChatId;
  String? currentChatId; // Track current chat ID

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
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
  }

  // Parse and format text with bold, italic, etc.
  Widget _buildFormattedText(String text, Color textColor) {
    final spans = <TextSpan>[];
    final RegExp boldRegex = RegExp(r'\*\*(.*?)\*\*');
    final RegExp italicRegex = RegExp(r'\*(.*?)\*');

    // Find all bold and italic patterns
    final allMatches = <MapEntry<int, String>>[];

    for (final match in boldRegex.allMatches(text)) {
      allMatches.add(MapEntry(match.start, 'bold:${match.group(1)}'));
    }

    for (final match in italicRegex.allMatches(text)) {
      // Skip if it's part of a bold pattern
      bool isPartOfBold = false;
      for (final boldMatch in boldRegex.allMatches(text)) {
        if (match.start >= boldMatch.start && match.end <= boldMatch.end) {
          isPartOfBold = true;
          break;
        }
      }
      if (!isPartOfBold) {
        allMatches.add(MapEntry(match.start, 'italic:${match.group(1)}'));
      }
    }

    // Sort matches by position
    allMatches.sort((a, b) => a.key.compareTo(b.key));

    // Build TextSpans
    int currentIndex = 0;
    for (final match in allMatches) {
      // Add normal text before the match
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

      // Add formatted text
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
        currentIndex = match.key + content.length + 4; // +4 for **...**
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
        currentIndex = match.key + content.length + 2; // +2 for *...*
      }
    }

    // Add remaining text
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

    // If no formatting found, return simple text
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

  // Format Gemini response with markdown formatting
  String _formatGeminiResponse(String label, String info) {
    return """🎯 **Prediction: ${label.toUpperCase()}**

📝 **Analysis:**
${info.replaceAll('. ', '.\n\n')}

💡 **Need more help?** *Feel free to ask questions about this plant!*""";
  }

  // ----------------------------------------------------------------------------------------------------------

  Future<void> sendMessage(ChatMessage message) async {
    // Check connectivity
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
      // Prepare request body with chat management
      final requestBody = {"message": message.text, "user_id": user.id};

      // Include chat_id if we have one
      if (currentChatId != null) {
        requestBody["chat_id"] = currentChatId!;
      }

      final res = await http
          .post(
            Uri.parse("http://10.0.2.2:5000/chat"),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        // Update current chat ID if this was a new chat
        if (data["is_new_chat"] == true || currentChatId == null) {
          currentChatId = data["chat_id"];
        }

        setState(() {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: botMsg.createdAt,
            text: data["response"] ?? "No reply received",
          );
        });
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

      final fileSize = await file.length();
      if (fileSize > 5 * 1024 * 1024) {
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
        Uri.parse("http://10.0.2.2:5000/analyze_image"),
      );

      request.headers.addAll({'Accept': 'application/json'});

      // Add user_id and chat_id to form data
      request.fields['user_id'] = user.id;
      if (currentChatId != null) {
        request.fields['chat_id'] = currentChatId!;
      }

      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          pickedFile.path,
          filename: pickedFile.name,
          contentType: http_parser.MediaType('image', 'jpeg'),
        ),
      );

      // Use a logging framework or remove in production
      print("Sending image: ${pickedFile.name}, Size: $fileSize bytes"); //Dont try to change

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 90),
      );
      final res = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        print("Response status: ${res.statusCode}");
      }
      if (kDebugMode) {
        print("Response body: ${res.body}");
      }

      if (res.statusCode == 200) {
        try {
          final data = json.decode(res.body);

          // Update current chat ID if this was a new chat
          if (data["is_new_chat"] == true || currentChatId == null) {
            currentChatId = data["chat_id"];
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
        } catch (jsonError) {
          setState(() {
            messages[0] = ChatMessage(
              user: bot,
              createdAt: botMsg.createdAt,
              text: "❌ Invalid response format from server",
            );
          });
          if (kDebugMode) {
            print("JSON decode error: $jsonError");
          }
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
      setState(() {
        if (messages.isNotEmpty && messages[0].user.id == bot.id) {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: DateTime.now(),
            text: "❌ Request timeout. Please try again with a smaller image.",
          );
        }
      });
      _showSnackBar("Request timeout - try a smaller image");
    } on SocketException {
      setState(() {
        if (messages.isNotEmpty && messages[0].user.id == bot.id) {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: DateTime.now(),
            text:
                "❌ Cannot connect to server. Please check if your server is running.",
          );
        }
      });
      _showSnackBar("Server connection failed");
    } on FormatException catch (e) {
      setState(() {
        if (messages.isNotEmpty && messages[0].user.id == bot.id) {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: DateTime.now(),
            text: "❌ Invalid server response format.",
          );
        }
      });
      _showSnackBar("Invalid response format: ${e.message}");
    } catch (e) {
      setState(() {
        if (messages.isNotEmpty && messages[0].user.id == bot.id) {
          messages[0] = ChatMessage(
            user: bot,
            createdAt: DateTime.now(),
            text: "❌ Error processing image. Please try again.",
          );
        }
      });
      _showSnackBar("Image processing error: ${e.toString()}");
      if (kDebugMode) {
        print("Detailed error: $e");
      }
    } finally {
      setState(() => isLoading = false);
    }
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

  void _closeSidebar() {
    setState(() {
      isSidebarVisible = false;
    });
  }

  void _startNewChat() {
    setState(() {
      currentChatId = null;
      selectedChatId = null;
      messages.clear();
      _addWelcomeMessage();
      isSidebarVisible = false;
    });
  }

  void _onChatSelected(String chatId) async {
    setState(() {
      selectedChatId = chatId;
      currentChatId = chatId;
      isSidebarVisible = false;
      isLoading = true;
    });

    try {
      final userId = user.id;

      final res = await http.get(
        Uri.parse("http://10.0.2.2:5000/getChat?userId=$userId&chatId=$chatId"),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        final List<ChatMessage> loadedMessages =
            (data['messages'] as List)
                .map(
                  (msg) => ChatMessage(
                    user: msg['sender'] == "user" ? user : bot,
                    createdAt: DateTime.parse(msg['timestamp']),
                    text: msg['message'],
                  ),
                )
                .toList()
                .reversed
                .toList(); // DashChat expects most recent at start

        setState(() {
          messages.clear();
          messages.addAll(loadedMessages);
        });
      } else {
        _showSnackBar("Failed to load chat: ${res.statusCode}");
      }
    } catch (e) {
      _showSnackBar("Error loading chat: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
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
                  fontSize: 20,
                ),
              ),
              const Text(
                "Your Smart Farming Assistant",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Color.fromRGBO(0, 128, 0, 0.3),
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
            if (isLoading)
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
              DashChat(
                currentUser: user,
                onSend: sendMessage,
                messages: messages,
                inputOptions: InputOptions(
                  inputDecoration: InputDecoration(
                    hintText: "Ask about agriculture...",
                    hintStyle: TextStyle(
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
                    fillColor: Color.fromRGBO(255, 255, 255, 0.90),
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
                        onPressed: isLoading ? null : sendImage,
                        icon: Icon(
                          Icons.photo_camera_rounded,
                          color:
                              isLoading
                                  ? Colors.grey.shade400
                                  : Colors.green.shade700,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                messageOptions: MessageOptions(
                  currentUserContainerColor: Color.fromRGBO(67, 160, 71, 0.9),
                  containerColor: Color.fromRGBO(255, 255, 255, 0.95),
                  textColor: Colors.grey.shade800,
                  currentUserTextColor: Colors.white,
                  messagePadding: const EdgeInsets.all(16),
                  borderRadius: 7,
                  messageTextBuilder: (message, previousMessage, nextMessage) {
                    final textColor =
                        message.user.id == user.id
                            ? Colors.white
                            : Colors.grey.shade800;

                    return _buildFormattedText(message.text, textColor);
                  },
                  showTime: true,
                ),
              ),

              // The chat history sidebar container
              ChatHistorySidebarContainer(
                isVisible: isSidebarVisible,
                onClose: _closeSidebar,
                onChatSelected: _onChatSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
