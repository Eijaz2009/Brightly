import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../services/ai_config.dart';
import '../services/app_style.dart';

// ─── Data Model ──────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime time;

  ChatMessage({
    required this.text,
    required this.isUser,
    DateTime? time,
  }) : time = time ?? DateTime.now();
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class AIChatScreen extends StatefulWidget {
  final List<Map<String, dynamic>> scholarships;
  final String userName;

  const AIChatScreen({
    super.key,
    this.scholarships = const [],
    this.userName = '',
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  late AiConfigResult _aiConfig;

  Future<void> _loadApiKey() async {    final result = await AiConfig.resolve();
    _aiConfig = result;
    debugPrint(
      'AiConfig: ready=${result.isReady} '
      'source=${result.source == null ? '-' : AiConfig.labelFor(result.source!)} '
      'failure=${result.failure}',
    );
  }

  String _buildSystemPrompt() {
    final userCtx = widget.userName.isNotEmpty
        ? 'Nama pengguna: ${widget.userName}.\n'
        : '';

    String scholarshipCtx = '';
    if (widget.scholarships.isNotEmpty) {
      final list = widget.scholarships.take(15).map((s) {
        return '• ${s['title'] ?? '-'} | ${s['country'] ?? '-'} | ${s['level'] ?? '-'} | Deadline: ${s['deadline'] ?? 'Varies'} | Funding: ${s['funding'] ?? 'N/A'}';
      }).join('\n');
      scholarshipCtx = '''
DATA BEASISWA TERKINI DI BRIGHTLY APP:
$list

Jika pengguna bertanya soal beasiswa yang ada di list ini, berikan info yang relevan dan spesifik.\n''';
    }

    return '''
Kamu adalah Brightly AI, asisten cerdas khusus beasiswa dari aplikasi Brightly.
Tugasmu membantu mahasiswa Indonesia menemukan, memahami, dan mempersiapkan diri untuk berbagai beasiswa.
$userCtx$scholarshipCtx
Keahlianmu:
- Beasiswa lokal: KIP Kuliah, LPDP, Beasiswa Unggulan, Beasiswa Baznas, dll
- Beasiswa internasional: Chevening, Fulbright, DAAD, AAS, Monbukagakusho, dll
- Tips esai, SoP, Letter of Intent
- Persiapan wawancara & dokumen
- Perbandingan beasiswa sesuai profil pengguna

Gaya komunikasi:
- Ramah, supportif, memotivasi seperti kakak berpengalaman
- Bahasa Indonesia natural
- Jawaban terstruktur dengan bullet atau nomor
- Maksimal ~300 kata
- Jika tidak tahu, arahkan ke sumber resmi

Mulai dengan antusias dan selalu siap membantu!
''';
  }

  late GenerativeModel _model;
  late ChatSession _chat;
  bool _modelReady = false;

  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _lastErrorMessage = '';

  late AnimationController _typingAnimController;
  late Animation<double> _dot1, _dot2, _dot3;

  final List<String> _suggestions = [
    '📚 Beasiswa S2 luar negeri?',
    '🎓 Tips lolos LPDP?',
    '📝 Cara nulis SoP yang bagus?',
    '💰 Beasiswa fully funded apa aja?',
    '📅 Deadline beasiswa terdekat?',
  ];

  @override
  void initState() {
    super.initState();
    _setupTypingAnimation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initModel();
    });
  }

  void _setupTypingAnimation() {
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _dot1 = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeInOut),
      ),
    );
    _dot2 = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeInOut),
      ),
    );
    _dot3 = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _typingAnimController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );
  }

  // Daftar model yang akan dicoba jika satu gagal
  final List<String> _modelNames = [
    'gemini-2.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-pro'
  ];
  int _currentModelIndex = 0;

  void _initModel() async {
    setState(() {
      _hasError = false;
      _isLoading = false;
    });

    await _loadApiKey();

    if (!_aiConfig.isReady) {
      setState(() {
        _hasError = true;
        _lastErrorMessage =
            _aiConfig.failure == AiConfigFailure.permissionDenied
                ? _aiConfig.detail
                : 'Fitur AI belum siap dipakai karena Gemini API key belum '
                      'dikonfigurasi di aplikasi ini.';
      });
      return;
    }

    _currentModelIndex = 0;
    _setupModel(_modelNames[_currentModelIndex]);
  }

  void _setupModel(String modelName) {
    try {
      _model = GenerativeModel(
        model: modelName,
        apiKey: _aiConfig.apiKey,
        systemInstruction: Content.system(_buildSystemPrompt()),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 800,
        ),
      );

      _chat = _model.startChat();

      if (_messages.isEmpty) {
        final name =
            widget.userName.isNotEmpty
            ? widget.userName.split(' ').first
            : 'kamu';
        final scholarshipNote =
            widget.scholarships.isNotEmpty
            ? '\n\nAku punya data **${widget.scholarships.length} beasiswa** terkini di Brightly yang bisa aku rekomendasikan untukmu! 🎯'
            : '';

        setState(() {
          _messages.add(
            ChatMessage(
              text: 'Halo $name! Aku **Brightly AI** 🎓$scholarshipNote\n\n'
                  'Aku bisa bantu kamu:\n'
                  '• Cari beasiswa yang cocok untuk profilmu\n'
                  '• Tips nulis esai & SoP yang menang\n'
                  '• Info syarat & deadline beasiswa\n'
                  '• Persiapan wawancara\n\n'
                  'Mau mulai dari mana nih? 😊',
              isUser: false,
            ),
          );
        });
      }

      setState(() {
        _modelReady = true;
        _hasError = false;
      });
      debugPrint('✅ Model initialized: $modelName');
    } catch (e) {
      debugPrint('❌ Failed to init model $modelName: $e');
      _lastErrorMessage = e.toString();
      _tryNextModel();
    }
  }

  void _tryNextModel() {
    if (_currentModelIndex < _modelNames.length - 1) {
      _currentModelIndex++;
      _setupModel(_modelNames[_currentModelIndex]);
    } else {
      setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _typingAnimController.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent,
          );
        }
      }
    });
  }

  Future<void> _sendMessage(String text, {bool isRetry = false}) async {
    if (text.trim().isEmpty) return;
    if (_isLoading && !isRetry) return;
    if (!isRetry && !_modelReady) {
      _toast('AI belum siap. Coba lagi sebentar.');
      return;
    }

    final userText = text.trim();
    if (!isRetry) _textController.clear();

    setState(() {
      if (!isRetry) _messages.add(ChatMessage(text: userText, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      // Menggunakan streaming agar respon terasa lebih hidup dan profesional
      final responseStream = _chat.sendMessageStream(Content.text(userText)).timeout(
        const Duration(seconds: 40),
      );
      
      String fullResponse = '';
      bool isFirstChunk = true;

      await for (final chunk in responseStream) {
        if (chunk.text != null) {
          fullResponse += chunk.text!;
          
          if (mounted) {
            setState(() {
              if (isFirstChunk) {
                _messages.add(ChatMessage(text: fullResponse, isUser: false));
                isFirstChunk = false;
                _isLoading = false; // Stop loading when first chunk arrives
              } else {
                // Update last message
                _messages[_messages.length - 1] = ChatMessage(
                  text: fullResponse,
                  isUser: false,
                  time: _messages.last.time,
                );
              }
            });
            _scrollToBottom();
          }
        }
      }
    } catch (e) {
      debugPrint('AI Chat Error: $e');
      
      // Jika error karena model tidak ditemukan atau timeout, coba ganti model otomatis
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('not found') || 
          errorStr.contains('supported') || 
          errorStr.contains('timeout') || 
          errorStr.contains('deadline exceeded')) {
        
        debugPrint('🔄 Model error or timeout detected, trying fallback...');
        if (_currentModelIndex < _modelNames.length - 1) {
          _currentModelIndex++;
          _setupModel(_modelNames[_currentModelIndex]);
          // Kirim ulang pesan dengan model baru
          _sendMessage(userText, isRetry: true);
          return;
        }
      }

      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Maaf, ada gangguan teknis: $e\n\nSedang mencoba memperbaiki diri...',
            isUser: false,
          ));
          _isLoading = false;
        });
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppStyle.getBackgroundColor(context),
      body: Column(
        children: [
          _buildHeader(isDark),
          Expanded(
            child: _hasError
                ? _buildErrorState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length +
                        (_isLoading ? 1 : 0) +
                        (_messages.length == 1 ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_messages.length == 1 && index == 1) {
                        return _buildSuggestions();
                      }
                      final msgIndex =
                          (_messages.length == 1 && index > 1) ? index - 1 : index;

                      if (msgIndex < _messages.length) {
                        return _buildMessageBubble(_messages[msgIndex], isDark);
                      }
                      return _buildTypingIndicator(isDark);
                    },
                  ),
          ),
          // Hide the composer while the error screen is up: typing into a
          // dead chat only confused people.
          if (!_hasError) _buildInputArea(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      decoration: const BoxDecoration(
        color: AppStyle.primaryBlue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 20, 20),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 44,
                height: 44,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Image.asset('assets/images/logo_combined.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Brighties AI',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppStyle.spark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Scholarship Expert · Online',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (_messages.length > 1)
                GestureDetector(
                  onTap: _clearChat,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.refresh_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearChat() {
    if (!_modelReady) return;
    setState(() {
      _isLoading = false;
      _messages.clear();
      _chat = _model.startChat();
      _messages.add(
        ChatMessage(
          text:
              'Halo! Aku **Brightly AI** 👋\n\nChat direset. Aku siap bantu lagi! '
              'Ada yang mau ditanyakan soal beasiswa? 😊',
          isUser: false,
        ),
      );
    });
  }

  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Pertanyaan populer:',
              style: GoogleFonts.plusJakartaSans(
                color: AppStyle.getSubtitleColor(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) {
              return GestureDetector(
                onTap: () => _sendMessage(s),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppStyle.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppStyle.primaryBlue.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    s,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppStyle.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, bool isDark) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppStyle.primaryBlue, AppStyle.deepBlue],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 16),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? AppStyle.primaryBlue
                    : null,
                gradient: isUser
                    ? null
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF0A0A0A), const Color(0xFF000000)]
                            : [Colors.white, const Color(0xFFF0F0F0)],
                      ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? AppStyle.primaryBlue : Colors.black)
                        .withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isUser 
                      ? Colors.transparent 
                      : AppStyle.getBorderColor(context).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormattedText(msg.text, isUser, isDark),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(msg.time),
                    style: GoogleFonts.plusJakartaSans(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppStyle.getSubtitleColor(context),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isUser) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.copy_rounded, size: 16, color: AppStyle.getSubtitleColor(context).withValues(alpha: 0.5)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pesan disalin ke clipboard', style: GoogleFonts.plusJakartaSans(fontSize: 12)),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                    width: 200,
                  ),
                );
              },
            ),
          ],
          if (isUser)
            Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: AppStyle.accentOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_rounded,
                  color: AppStyle.accentOrange, size: 18),
            ),
        ],
      ),
    );
  }

  Widget _buildFormattedText(String text, bool isUser, bool isDark) {
    final baseColor = isUser ? Colors.white : AppStyle.getTextColor(context);
    final accentColor = isUser ? Colors.white70 : AppStyle.primaryBlue;
    final lines = text.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        if (line.startsWith('• ') || line.startsWith('- ') || line.startsWith('* ')) {
          final content = line.substring(2);
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: GoogleFonts.plusJakartaSans(color: accentColor, fontSize: 14, fontWeight: FontWeight.w700)),
                Flexible(child: _buildRichLine(content, baseColor)),
              ],
            ),
          );
        }
        final numMatch = RegExp(r'^(\d+)\. ').firstMatch(line);
        if (numMatch != null) {
          final num = numMatch.group(1)!;
          final content = line.substring(numMatch.end);
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$num. ', style: GoogleFonts.plusJakartaSans(color: accentColor, fontSize: 14, fontWeight: FontWeight.w700)),
                Flexible(child: _buildRichLine(content, baseColor)),
              ],
            ),
          );
        }
        if (line.trim().isEmpty) return const SizedBox(height: 4);
        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _buildRichLine(line, baseColor),
        );
      }).toList(),
    );
  }

  Widget _buildRichLine(String text, Color baseColor) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) spans.add(TextSpan(text: text.substring(lastEnd)));
    return RichText(
      text: TextSpan(
        style: GoogleFonts.plusJakartaSans(
          color: baseColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppStyle.primaryBlue, AppStyle.deepBlue],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 16),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0A0A0A) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppStyle.getBorderColor(context)),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimController,
              builder: (_, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDot(_dot1.value),
                    const SizedBox(width: 4),
                    _buildDot(_dot2.value),
                    const SizedBox(width: 4),
                    _buildDot(_dot3.value),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(double opacity) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppStyle.primaryBlue.withValues(alpha: 0.3 + opacity * 0.7),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppStyle.getBackgroundColor(context),
        border: Border(top: BorderSide(color: AppStyle.getBorderColor(context))),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppStyle.getBorderColor(context), width: 1.5),
              ),
              child: TextField(
                controller: _textController,
                maxLines: 4,
                minLines: 1,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppStyle.getTextColor(context)),
                decoration: InputDecoration(
                  hintText: 'Tanya tentang beasiswa...',
                  hintStyle: GoogleFonts.plusJakartaSans(color: AppStyle.getSubtitleColor(context), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) => _sendMessage(val),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_textController.text),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _isLoading
                      ? [Colors.grey.shade400, Colors.grey.shade400]
                      : [AppStyle.accentOrange, const Color(0xFF22C55E)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                _isLoading ? Icons.hourglass_top_rounded : Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Friendly, actionable failure screen.
  ///
  /// The previous version showed a bare "Gagal Inisialisasi AI" dead end, which
  /// gave the user no idea what to do. Now it names the cause and, for a missing
  /// key, spells out the exact setup steps.
  Widget _buildErrorState() {
    final missingKey =
        _aiConfig.failure == AiConfigFailure.missing ||
        _aiConfig.failure == AiConfigFailure.permissionDenied;
    final reasonKey = _lastErrorMessage.toLowerCase();

    final String headline;
    final String explain;
    if (missingKey && _aiConfig.failure == AiConfigFailure.permissionDenied) {
      headline = 'Belum bisa akses konfigurasi AI';
      explain =
          'Akun ini belum boleh membaca dokumen konfigurasi. Login ulang, lalu '
          'pastikan security rules Firestore sudah di-deploy.';
    } else if (missingKey) {
      headline = 'Fitur AI belum dikonfigurasi';
      explain =
          'Aplikasi belum menemukan Gemini API key, jadi asisten AI tidak bisa '
          'dijalankan. Admin cukup menambahkannya satu kali di Firestore.';
    } else if (reasonKey.contains('api key not valid') ||
        reasonKey.contains('permission_denied') ||
        reasonKey.contains('400')) {
      headline = 'API key ditolak';
      explain =
          'Gemini menolak API key yang tersimpan. Pastikan key masih aktif di '
          'Google AI Studio, lalu muat ulang.';
    } else if (reasonKey.contains('quota') ||
        reasonKey.contains('429') ||
        reasonKey.contains('resource_exhausted')) {
      headline = 'Kuota API habis';
      explain =
          'Batas pemakaian harian sudah tercapai. Coba lagi besok atau pakai '
          'project Google Cloud lain.';
    } else if (reasonKey.contains('network') || reasonKey.contains('failed to fetch')) {
      headline = 'Tidak ada koneksi';
      explain = 'Periksa koneksi internetmu, lalu muat ulang.';
    } else {
      headline = 'Asisten AI belum siap';
      explain = _lastErrorMessage.isEmpty
          ? 'Terjadi kendala teknis. Silakan coba lagi.'
          : _lastErrorMessage;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppStyle.sunny.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppStyle.sunny,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          headline,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppStyle.getTextColor(context),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          explain,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            height: 1.6,
            fontWeight: FontWeight.w500,
            color: AppStyle.getSubtitleColor(context),
          ),
        ),

        if (_aiConfig.failure == AiConfigFailure.missing) ...[
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppStyle.getCardColor(context),
              borderRadius: BorderRadius.circular(AppStyle.rMd),
              border: Border.all(color: AppStyle.getBorderColor(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      size: 16,
                      color: AppStyle.coral,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Cara mengaktifkan',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppStyle.getTextColor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < AiConfig.setupSteps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppStyle.ink,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            AiConfig.setupSteps[i],
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              height: 1.45,
                              fontWeight: FontWeight.w500,
                              color: AppStyle.getSubtitleColor(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],

        // Diagnostics, so a developer can see exactly what was resolved.
        const SizedBox(height: 16),
        Text(
          _aiConfig.isReady
              ? 'Sumber key: ${AiConfig.labelFor(_aiConfig.source!)}'
              : 'Status: ${_aiConfig.detail.isEmpty ? 'tidak ditemukan' : _aiConfig.detail}',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppStyle.getSubtitleColor(context),
          ),
        ),

        const SizedBox(height: 24),
        AppStyle.primaryButton(
          context: context,
          label: 'Muat ulang',
          icon: Icons.refresh_rounded,
          color: AppStyle.ink,
          onPressed: _initModel,
        ),
        const SizedBox(height: 10),
        AppStyle.primaryButton(
          context: context,
          label: 'Kembali',
          icon: Icons.arrow_back_rounded,
          color: AppStyle.getSandColor(context),
          expanded: false,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }
}
