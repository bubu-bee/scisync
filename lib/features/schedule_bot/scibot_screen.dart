import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// 1. THE NEW IMPORT
import 'package:firebase_ai/firebase_ai.dart';

class SciBotScreen extends StatefulWidget {
  const SciBotScreen({super.key});

  @override
  State<SciBotScreen> createState() => _SciBotScreenState();
}

class _SciBotScreenState extends State<SciBotScreen> {
  final TextEditingController _messageController = TextEditingController();

  // Stores the chat history for the UI
  final List<Map<String, String>> _messages = [];

  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isInitializing = true;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _initializeSciBot();
  }

  // This is where the magic happens! We fetch the database info and give it to Gemini.
  Future<void> _initializeSciBot() async {
    try {
      // 1. Fetch recent notices from Firestore to build context
      final snapshot = await FirebaseFirestore.instance
          .collection('notices')
          .orderBy('timestamp', descending: true)
          .limit(10)
          .get();

      // 2. Convert database documents into a readable string for the AI
      String dbContext =
          "Here are the latest university updates and notices:\n";
      for (var doc in snapshot.docs) {
        final data = doc.data();
        dbContext +=
            "- [${data['tag']}] ${data['title']}: ${data['description']}\n";
      }

      // 3. Create the Secret System Instruction
      String systemInstruction =
          """
You are SciBot, the official friendly AI assistant for the SciSync university app. 
Your job is to help students with their schedule and notices.
Always be concise, polite, and helpful. 
Use the following real-time database information to answer student questions:
$dbContext
""";

      // 4. Initialize Gemini 1.5 Flash using the NEW FirebaseAI architecture
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.0-flash',
        systemInstruction: Content.system(systemInstruction),
      );
      // 5. Start the chat session
      _chatSession = _model!.startChat();
    } catch (e) {
      debugPrint("Error initializing SciBot: $e");
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  Future<void> _sendMessage() async {
    final userText = _messageController.text.trim();
    if (userText.isEmpty || _chatSession == null) return;

    _messageController.clear();

    // Add user message to UI immediately
    setState(() {
      _messages.add({'sender': 'user', 'text': userText});
      _isTyping = true;
    });

    try {
      // Send message to Gemini and wait for response
      final response = await _chatSession!.sendMessage(Content.text(userText));

      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': response.text ?? 'Sorry, I got confused.',
        });
      });
    } catch (e) {
      debugPrint("🔥 GEMINI ERROR: $e");
      setState(() {
        _messages.add({
          'sender': 'bot',
          'text': 'Error: My servers are currently offline.',
        });
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.teal),
            SizedBox(width: 8),
            Text('SciBot', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal,
        elevation: 1,
      ),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator(color: Colors.teal))
          : Column(
              children: [
                // Chat Messages Area
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Ask me anything about your notices or schedule!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            final isUser = msg['sender'] == 'user';
                            return _buildChatBubble(msg['text']!, isUser);
                          },
                        ),
                ),

                // Typing Indicator
                if (_isTyping)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "SciBot is thinking...",
                        style: TextStyle(
                          color: Colors.teal,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                // Input Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12.0,
                    vertical: 8.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Type your question...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.0),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Helper widget to make chat bubbles look like a real messaging app
  Widget _buildChatBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isUser ? Colors.teal : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 16),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
