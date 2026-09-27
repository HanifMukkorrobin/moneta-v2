import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isAiTyping;
  final TextEditingController? controller;

  const ChatInputBar({
    super.key,
    required this.onSendMessage,
    this.isAiTyping = false,
    this.controller,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  late TextEditingController _controller;
  bool _hasText = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _hasText = _controller.text.trim().isNotEmpty;
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasNow = _controller.text.trim().isNotEmpty;
    if (hasNow != _hasText) {
      setState(() {
        _hasText = hasNow;
      });
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isAiTyping) return;
    widget.onSendMessage(text);
    _controller.clear();
  }

  void _simulateVoiceNote() {
    setState(() {
      _isRecording = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.mic, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('Mendengarkan... "Makan siang bakso 20rb"'),
          ],
        ),
        duration: Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
      });
      _controller.text = 'Makan siang bakso 20rb';
      _handleSend();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.borderSubtle),
        ),
      ),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Voice Input / Mic Button
            IconButton(
              icon: Icon(
                _isRecording ? Icons.mic : Icons.mic_none_rounded,
                color: _isRecording ? Colors.redAccent : AppTheme.textSecondary,
              ),
              tooltip: 'Catat via Suara (Simulasi)',
              onPressed: widget.isAiTyping || _isRecording
                  ? null
                  : _simulateVoiceNote,
            ),

            // Freeform Text Input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                child: TextField(
                  controller: _controller,
                  enabled: !widget.isAiTyping && !_isRecording,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSend(),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.isAiTyping
                        ? 'Menunggu balasan AI...'
                        : 'Ketik pesan bebas... mis. sarapan roti 12rb',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryColor, width: 1.2),
                    ),
                    suffixIcon: _hasText
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            color: AppTheme.textSecondary,
                            onPressed: () {
                              _controller.clear();
                            },
                          )
                        : null,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Send Button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: (_hasText && !widget.isAiTyping)
                    ? AppTheme.primaryColor
                    : AppTheme.borderSubtle,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: (_hasText && !widget.isAiTyping)
                      ? Colors.white
                      : AppTheme.textSecondary,
                  size: 20,
                ),
                onPressed: (_hasText && !widget.isAiTyping) ? _handleSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
