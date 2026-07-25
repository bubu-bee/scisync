import 'package:flutter/material.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import '../compiler/schedule_compiler.dart';

class SciBotChatScreen extends StatefulWidget {
 
  final Stream<List<Map<String, dynamic>>> scheduleStream;

  const SciBotChatScreen({super.key, required this.scheduleStream});

  @override
  State<SciBotChatScreen> createState() => _SciBotChatScreenState();
}

class _SciBotChatScreenState extends State<SciBotChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, String>> _messages = []; // Chat ඉතිහාසය සුරැකීමට
  
  final ScheduleCompiler _compiler = ScheduleCompiler();
  GenerativeModel? _model;
  ChatSession? _chatSession;
  bool _isLoading = false;
  String _systemInstructionText = "";

  @override
  void initState() {
    super.initState();
    
    widget.scheduleStream.listen((rawDocs) {
      final compiledItems = _compiler.compileRawData(rawDocs);
      setState(() {
        _systemInstructionText = _compiler.generateSystemInstruction(compiledItems);
        
        
        _model = FirebaseVertexAI.instance.generativeModel(
          model: 'gemini-1.5-flash',
          systemInstruction: Content.system(_systemInstructionText),
        );
        
        
        _chatSession = _model!.startChat();
      });
    });
  }

  void _sendMessage() async {
    final userMessage = _messageController.text.trim();
    if (userMessage.isEmpty || _chatSession == null) return;

    _messageController.clear();
    setState(() {
      _messages.add({'sender': 'user', 'text': userMessage});
      _isLoading = true;
    });

    try {
      
      final response = await _chatSession!.sendMessage(Content.text(userMessage));
      
      setState(() {
        _messages.add({'sender': 'bot', 'text': response.text ?? 'Sorry, I couldn\'t process that.'});
      });
    } catch (e) {
      setState(() {
        _messages.add({'sender': 'bot', 'text': 'Error: Failed to connect to SciBot.'});
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SciBot - Academic Assistant'),
      ),
      body: Column(
        children: [
          
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text('Ask me anything about your schedule!'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _messages.count,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg['sender'] == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft;
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4.0),
                          padding: const EdgeInsets.all(12.0),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue[100] : Colors.grey[200];
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: Text(msg['text'] ?? ''),
                        ),
                      );
                    },
                  ),
          ),
          
          if (_isLoading) const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ),

          
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type your question...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
