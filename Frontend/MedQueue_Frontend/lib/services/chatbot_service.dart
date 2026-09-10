import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/chatbot_model.dart';
import '../utils/token_manager.dart';

class ChatbotService extends ChangeNotifier {
  final List<ChatThread> _threads = [];
  String? _activeThreadId;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isHistoryLoaded = false;

  List<ChatMessage> get messages => activeThread?.messages ?? const [];
  List<ChatThread> get threads =>
      List<ChatThread>.from(_threads)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  String? get activeThreadId => _activeThreadId;
  ChatThread? get activeThread {
    if (_activeThreadId == null) return null;
    for (final thread in _threads) {
      if (thread.id == _activeThreadId) {
        return thread;
      }
    }
    return null;
  }
  String get activeThreadTitle => activeThread?.title ?? 'New chat';
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  static const List<String> _groqModels = [
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
    'qwen/qwen3.6-27b',
    'allam-2-7b',
  ];

  late final String _groqApiKey;
  final String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  final String _chatStorageKeyPrefix = 'chat_threads_';

  ChatbotService() {
    _groqApiKey = dotenv.env['GROQ_API_KEY'] ?? '';
    loadChatHistory();
  }

  String _createTitleFromMessage(String userMessage) {
    final trimmed = userMessage.trim();
    if (trimmed.isEmpty) return 'New chat';
    if (trimmed.length <= 36) return trimmed;
    return '${trimmed.substring(0, 36)}...';
  }

  Future<void> _ensureActiveThread() async {
    if (activeThread != null) return;
    await createNewChat(notify: false);
  }

  int _activeThreadIndex() {
    if (_activeThreadId == null) return -1;
    return _threads.indexWhere((thread) => thread.id == _activeThreadId);
  }

  Future<void> createNewChat({bool notify = true}) async {
    final now = DateTime.now();
    final thread = ChatThread(
      id: const Uuid().v4(),
      title: 'New chat',
      messages: const [],
      createdAt: now,
      updatedAt: now,
    );
    _threads.add(thread);
    _activeThreadId = thread.id;
    _errorMessage = null;
    await _persistThreads();
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> switchThread(String threadId) async {
    final exists = _threads.any((thread) => thread.id == threadId);
    if (!exists) return;
    _activeThreadId = threadId;
    _errorMessage = null;
    await _persistThreads();
    notifyListeners();
  }

  Future<void> deleteThread(String threadId) async {
    _threads.removeWhere((thread) => thread.id == threadId);
    if (_threads.isEmpty) {
      await createNewChat(notify: false);
    } else if (_activeThreadId == threadId) {
      _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _activeThreadId = _threads.first.id;
    }
    await _persistThreads();
    notifyListeners();
  }

  Future<String> _currentUserChatStorageKey() async {
    final user = await TokenManager.getCachedUserData();
    if (user != null) {
      return '$_chatStorageKeyPrefix${user.id}';
    }
    return '${_chatStorageKeyPrefix}guest';
  }

  Future<void> loadChatHistory({bool forceReload = false}) async {
    if (_isHistoryLoaded && !forceReload) {
      return;
    }

    try {
      final key = await _currentUserChatStorageKey();
      final raw = await TokenManager.readRaw(key);
      _threads.clear();
      _activeThreadId = null;

      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        // Migration: old single-chat format was a top-level list of messages.
        if (decoded is List<dynamic>) {
          final migratedMessages = decoded
              .map((item) => ChatMessage.fromJson(item as Map<String, dynamic>))
              .toList();
          final now = DateTime.now();
          final migratedThread = ChatThread(
            id: const Uuid().v4(),
            title: migratedMessages.isNotEmpty
                ? _createTitleFromMessage(
                    migratedMessages.firstWhere(
                      (m) => m.isUser,
                      orElse: () => migratedMessages.first,
                    ).content,
                  )
                : 'New chat',
            messages: migratedMessages,
            createdAt: now,
            updatedAt: now,
          );
          _threads.add(migratedThread);
          _activeThreadId = migratedThread.id;
          await _persistThreads();
        } else if (decoded is Map<String, dynamic>) {
          final rawThreads = decoded['threads'] as List<dynamic>? ?? [];
          for (final item in rawThreads) {
            _threads.add(ChatThread.fromJson(item as Map<String, dynamic>));
          }
          _activeThreadId = decoded['active_thread_id'] as String?;
        }
      }

      if (_threads.isEmpty) {
        await createNewChat(notify: false);
      }

      if (activeThread == null && _threads.isNotEmpty) {
        _threads.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        _activeThreadId = _threads.first.id;
      }
    } catch (_) {
      // If history fails to parse/load, keep chat usable with an empty state.
      _threads.clear();
      _activeThreadId = null;
      await createNewChat(notify: false);
    } finally {
      _isHistoryLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _persistThreads() async {
    final key = await _currentUserChatStorageKey();
    final serialized = {
      'active_thread_id': _activeThreadId,
      'threads': _threads.map((thread) => thread.toJson()).toList(),
    };
    await TokenManager.writeRaw(key, jsonEncode(serialized));
  }

  // System instructions to ensure the health bot acts safely and structured
final String _systemPrompt = '''
    You are an AI Health Assistant providing structured educational information and first-aid guidance. 
    
    Strictly follow these response formatting and safety rules:
    1. Use Markdown headers (###) to separate sections like Symptoms, Actionable Advice, and Tips.
    2. Use standard bullet points (* or -) for lists, and nested bullet points for sub-items.
    3. Use bolding (**text**) generously to highlight critical key phrases, drug classes, or symptoms.
    4. Never diagnose a condition or prescribe specific medical dosages. Use inline code (e.g., `Consult a doctor`) if mentioning general medication categories.
    5. Always format your mandatory closing disclaimer inside a markdown blockquote (starting each line with >) so it stands out visually as a warning box.
    6. If comparing items or timelines, format them into a clean markdown table.
  ''';

  // Format bot response for better readability
  String _formatBotResponse(String rawResponse) {
    // Split by newlines and filter out excessive whitespace
    final lines = rawResponse.split('\n');
    final formattedLines = <String>[];
    bool inParagraph = false;

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (inParagraph) {
          formattedLines.add(''); // Add blank line between paragraphs
          inParagraph = false;
        }
      } else {
        formattedLines.add(trimmed);
        inParagraph = true;
      }
    }

    // Remove trailing empty lines
    while (formattedLines.isNotEmpty && formattedLines.last.isEmpty) {
      formattedLines.removeLast();
    }

    return formattedLines.join('\n');
  }

  // Send message to chatbot
  Future<void> sendMessage(String userMessage) async {
    await loadChatHistory();
    await _ensureActiveThread();

    final activeIndex = _activeThreadIndex();
    if (activeIndex < 0) {
      _errorMessage = 'Unable to send message. Please start a new chat.';
      notifyListeners();
      return;
    }

    final currentThread = _threads[activeIndex];
    final updatedMessages = List<ChatMessage>.from(currentThread.messages);

    // Add user message to UI
    updatedMessages.add(
      ChatMessage(
        id: const Uuid().v4(),
        content: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    final updatedTitle = currentThread.title == 'New chat'
        ? _createTitleFromMessage(userMessage)
        : currentThread.title;
    _threads[activeIndex] = currentThread.copyWith(
      title: updatedTitle,
      messages: updatedMessages,
      updatedAt: DateTime.now(),
    );
    await _persistThreads();

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Build conversation payload for context memory
      List<Map<String, String>> historyPayload = [
        {"role": "system", "content": _systemPrompt}
      ];

      // Add recent context history if needed, or just append the last few messages
      for (final msg in _threads[activeIndex].messages) {
        historyPayload.add({
          "role": msg.isUser ? "user" : "assistant",
          "content": msg.content,
        });
      }

      String? lastModelError;
      final List<String> models = dotenv.env.containsKey('GROQ_MODEL')
          ? [dotenv.env['GROQ_MODEL']!]
          : _groqModels;
      late http.Response response;
      Map<String, dynamic> data = const <String, dynamic>{};

      for (final model in models) {
        response = await http.post(
          Uri.parse(_groqUrl),
          headers: {
            'Authorization': 'Bearer $_groqApiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': historyPayload,
            'temperature': 0.5,
            'max_tokens': 1024,
          }),
        );

        if (response.statusCode == 200) {
          data = jsonDecode(utf8.decode(response.bodyBytes));
          break;
        }

        String apiError = 'Unknown API Error';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);
          apiError =
              errorData['error']?['message']?.toString() ?? 'Unknown API Error';
        } catch (_) {
          apiError = 'HTTP ${response.statusCode}';
        }

        // Retry the next model only when Groq rejects the model name itself.
        final bool isModelAccessError =
            (response.statusCode == 400 || response.statusCode == 404) &&
                apiError.toLowerCase().contains('does not exist');
        if (isModelAccessError) {
          lastModelError = apiError;
          continue;
        }
        throw Exception(apiError);
      }

      if (data.isEmpty) {
        throw Exception(lastModelError ?? 'Unknown API Error');
      }

      final String rawResponse = data['choices'][0]['message']['content'].toString();
      final String botResponse = _formatBotResponse(rawResponse);

      // Add bot message
      final botMessages = List<ChatMessage>.from(_threads[activeIndex].messages);
      botMessages.add(
        ChatMessage(
          id: const Uuid().v4(),
          content: botResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      _threads[activeIndex] = _threads[activeIndex].copyWith(
        messages: botMessages,
        updatedAt: DateTime.now(),
      );
      await _persistThreads();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to get response: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
    }
  }

  // Clear chat history
  Future<void> clearMessages() async {
    await _ensureActiveThread();
    final activeIndex = _activeThreadIndex();
    if (activeIndex >= 0) {
      _threads[activeIndex] = _threads[activeIndex].copyWith(
        title: 'New chat',
        messages: [],
        updatedAt: DateTime.now(),
      );
    }
    _errorMessage = null;
    await _persistThreads();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}