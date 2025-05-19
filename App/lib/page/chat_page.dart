import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:iot_app/components/chat_message.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late final GenerativeModel _model;

  final apiKey = dotenv.env['API_KEY']!;
  final apiModel = dotenv.env['API_MODEL']!;

  @override
  void initState() {
    super.initState();
    _model = GenerativeModel(
      model: apiModel,
      apiKey: apiKey,
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    final userMessage = ChatMessage(role: 'user', content: input);

    setState(() {
      _messages.add(userMessage);
      _controller.clear();
    });

    _scrollToBottom();

    try {
      final response = await _model.generateContent([Content.text(input)]);

      final aiResponse = ChatMessage(
        role: 'ai',
        content: response.text?.trim() ?? 'No response received',
      );

      setState(() {
        _messages.add(aiResponse);
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(
            ChatMessage.error('Service unavailable. Please try again later.'));
      });

      _scrollToBottom();
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy Information'),
        content: const Text(
          'Your chat history will not be stored or utilized for training the model or any other purposes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _clearMessages() {
    setState(() {
      _messages.clear();
    });
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.role == 'user';
    final isError = message.isError;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isError
              ? Colors.red[100]
              : isUser
                  ? const Color.fromRGBO(146, 227, 169, 1)
                  : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isError)
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
          ],
        ),
        child: MarkdownBody(
          data: message.content,
          styleSheet: MarkdownStyleSheet(
            h1: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            h2: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            h3: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            p: TextStyle(
              color: isError
                  ? Colors.red[800]
                  : isUser
                      ? Colors.white
                      : Colors.black87,
              fontSize: 16,
            ),
            code: const TextStyle(
              backgroundColor: Color(0xFFEEEEEE),
              fontFamily: 'Courier',
            ),
            strong: const TextStyle(fontWeight: FontWeight.bold),
            em: const TextStyle(fontStyle: FontStyle.italic),
            a: const TextStyle(decoration: TextDecoration.underline),
            blockquotePadding: const EdgeInsets.all(8),
            blockquoteDecoration: const BoxDecoration(
              color: Color(0xFFF5F5F5),
              border: Border(left: BorderSide(color: Colors.grey, width: 4)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundImage: AssetImage('assets/icons8-doctor.png'),
              radius: 20,
            ),
            const SizedBox(width: 8),
            const Text(
              'WellSync Assistant',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.verified,
                color: Color.fromRGBO(146, 227, 169, 1), size: 20),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            color: Colors.transparent,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'How can I help you?',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                  color: const Color.fromRGBO(146, 227, 169, 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
