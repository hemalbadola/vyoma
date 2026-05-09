import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:desktop_drop/desktop_drop.dart';
import '../../tutorial/tutorial_keys.dart';
import '../theme/vyoma_colors.dart';
import '../war_room_viewmodel.dart';
import 'pending_action_card.dart';

sealed class _ChatBlock {
  const _ChatBlock();
}

final class _BlkSys extends _ChatBlock {
  const _BlkSys(this.msg);
  final ChatMessage msg;
}

final class _BlkGrp extends _ChatBlock {
  const _BlkGrp(this.sender, this.msgs);
  final String sender;
  final List<ChatMessage> msgs;
}

class ChatSheetPresentation {
  static int presentCount = 0;
}

class ChatSheet extends StatefulWidget {
  const ChatSheet({super.key});

  /// Slide-up route used everywhere War Room chat is opened (tutorial + manual).
  static PageRoute<void> slideUpRoute() {
    return PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'vyoma_chat_sheet'),
      pageBuilder: (context, animation, secondaryAnimation) => const ChatSheet(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: Curves.easeOutQuart));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  // Slash command autocomplete state
  bool _showCommandSuggestions = false;
  List<MapEntry<String, List<String>>> _filteredCommands = [];

  bool _isDragging = false;

  /// When non-null and equal to the latest error line, the inline banner stays hidden.
  String? _suppressedBannerText;

  @override
  void initState() {
    super.initState();
    ChatSheetPresentation.presentCount++;
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    ChatSheetPresentation.presentCount--;
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    if (text.startsWith('/')) {
      final query = text.toLowerCase();
      final filtered = WarRoomViewModel.commandHelp.entries
          .where((e) => e.key.startsWith(query) || e.value[0].toLowerCase().contains(query.substring(1)))
          .toList();
      setState(() {
        _showCommandSuggestions = filtered.isNotEmpty;
        _filteredCommands = filtered;
      });
    } else {
      if (_showCommandSuggestions) {
        setState(() {
          _showCommandSuggestions = false;
          _filteredCommands = [];
        });
      }
    }
  }

  void _selectCommand(String command) {
    // Commands that take arguments: add a space so user can type the arg
    final needsArg = ['/focus start', '/remember', '/forget', '/goal', '/blocker', '/task add'];
    if (needsArg.contains(command)) {
      _controller.text = '$command ';
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
    } else {
      // Direct commands: execute immediately
      final vm = context.read<WarRoomViewModel>();
      vm.submitCommand(command);
      _controller.clear();
    }
    setState(() {
      _showCommandSuggestions = false;
      _filteredCommands = [];
    });
    _focusNode.requestFocus();
  }

  String _formatTime(DateTime t) {
    final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:$minute $ampm';
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Command icon mapper for autocomplete
  IconData _commandIcon(String cmd) {
    if (cmd.startsWith('/focus')) return Icons.center_focus_strong_rounded;
    if (cmd.startsWith('/task')) return Icons.task_alt_rounded;
    if (cmd == '/remember') return Icons.lightbulb_outline_rounded;
    if (cmd == '/forget') return Icons.delete_sweep_rounded;
    if (cmd == '/memories') return Icons.psychology_rounded;
    if (cmd == '/stats') return Icons.insights_rounded;
    if (cmd == '/goal') return Icons.flag_rounded;
    if (cmd == '/blocker') return Icons.block_rounded;
    if (cmd == '/schedule') return Icons.calendar_today_rounded;
    if (cmd == '/undo') return Icons.undo_rounded;
    if (cmd == '/clear history') return Icons.cleaning_services_rounded;
    if (cmd == '/approve') return Icons.check_circle_outline_rounded;
    if (cmd == '/deny') return Icons.cancel_outlined;
    if (cmd == '/help') return Icons.help_outline_rounded;
    return Icons.terminal_rounded;
  }

  bool _isChatErrorBannerText(String raw) {
    final t = raw.toLowerCase();
    if (t.contains('metric integrity')) return false;
    return t.contains('failed') ||
        t.contains('unavailable') ||
        t.contains('authorization failed') ||
        t.contains('error');
  }

  String? _latestErrorBannerText(List<ChatMessage> messages) {
    for (final m in messages.reversed) {
      if (m.sender != 'SYSTEM') continue;
      if (_isChatErrorBannerText(m.text)) return m.text;
    }
    return null;
  }

  List<_ChatBlock> _chatBlocksFromMessages(List<ChatMessage> messages) {
    final blocks = <_ChatBlock>[];
    List<ChatMessage>? grp;
    String? grpSender;

    void flushGrp() {
      if (grp != null && grp!.isNotEmpty && grpSender != null) {
        blocks.add(_BlkGrp(grpSender!, grp!));
        grp = null;
        grpSender = null;
      }
    }

    for (final m in messages) {
      if (m.sender == 'SYSTEM' && m.text.startsWith('[THOUGHT]')) continue;

      if (m.sender == 'SYSTEM') {
        flushGrp();
        blocks.add(_BlkSys(m));
        continue;
      }

      if (m.sender == grpSender) {
        grp!.add(m);
      } else {
        flushGrp();
        grpSender = m.sender;
        grp = [m];
      }
    }
    flushGrp();
    return blocks;
  }

  Widget _buildErrorBannerStrip(WarRoomViewModel vm) {
    final latest = _latestErrorBannerText(vm.messages);
    if (latest == null || latest == _suppressedBannerText) {
      return const SizedBox.shrink();
    }
    final cleaned = latest.startsWith('> ') ? latest.substring(2) : latest;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: VyomaColors.error.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: VyomaColors.error.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline_rounded, color: VyomaColors.error.withValues(alpha: 0.85), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cleaned,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.55), size: 20),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _suppressedBannerText = latest),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiVyomaHeaderRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VyomaColors.info,
              boxShadow: [
                BoxShadow(
                  color: VyomaColors.info.withValues(alpha: 0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Vyoma',
            style: GoogleFonts.jetBrainsMono(
              color: VyomaColors.accentBright,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemLine(ChatMessage msg, Color kAccentDim) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: kAccentDim.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Text(
              msg.text,
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white30,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupBubbleColumn({
    required BuildContext context,
    required String sender,
    required List<ChatMessage> msgs,
    required double bubbleMaxWidth,
    required Color kAccent,
  }) {
    final isUser = sender == 'USER';

    final bubbleBg = isUser ? VyomaColors.bgCardHover : VyomaColors.bgCardElevated;
    final bubbleBorder = isUser ? VyomaColors.borderDefault : VyomaColors.borderSubtle;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bubbleMaxWidth),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < msgs.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _singleBubble(
                msg: msgs[i],
                isUser: isUser,
                kAccent: kAccent,
                bubbleBg: bubbleBg,
                bubbleBorder: bubbleBorder,
                showVyomaHeader: !isUser && i == 0,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isUser) ...[
                  _CopyButton(text: _joinedText(msgs)),
                  const SizedBox(width: 6),
                ],
                Text(
                  _formatTime(msgs.last.timestamp),
                  style: GoogleFonts.jetBrainsMono(
                    color: VyomaColors.textMuted,
                    fontSize: 10,
                    height: 1.1,
                  ),
                ),
                if (!isUser) ...[
                  const SizedBox(width: 6),
                  _CopyButton(text: _joinedText(msgs)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Concatenate grouped bubble texts so the copy button captures the full
  /// reply (or full user message) the user actually sees.
  static String _joinedText(List<ChatMessage> msgs) {
    return msgs.map((m) => m.text).where((t) => t.isNotEmpty).join('\n\n');
  }

  Widget _singleBubble({
    required ChatMessage msg,
    required bool isUser,
    required Color kAccent,
    required Color bubbleBg,
    required Color bubbleBorder,
    required bool showVyomaHeader,
  }) {
    final isCommandOutput =
        (!isUser && msg.text.startsWith('Available commands:')) ||
            (!isUser && msg.text.startsWith('Productivity Stats:'));

    return GestureDetector(
      onLongPress: () {},
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCommandOutput ? 20 : 16,
          vertical: isCommandOutput ? 16 : 12,
        ),
        decoration: BoxDecoration(
          color: bubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 20),
          ),
          border: Border.all(color: bubbleBorder, width: 0.5),
          boxShadow: isUser
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showVyomaHeader) _buildAiVyomaHeaderRow(),
            if (msg.imageBytes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    msg.imageBytes!,
                    fit: BoxFit.cover,
                    height: 150,
                  ),
                ),
              ),
            if (isUser && msg.text.startsWith('/'))
              Text(
                msg.text,
                style: GoogleFonts.jetBrainsMono(
                  color: kAccent,
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                msg.text,
                style: isUser
                    ? GoogleFonts.inter(color: VyomaColors.textPrimary, fontSize: 15, height: 1.5)
                    : GoogleFonts.inter(
                        color: VyomaColors.textPrimary.withValues(alpha: 0.92),
                        fontSize: 14.5,
                        height: 1.6,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingBubble(BuildContext context, WarRoomViewModel vm, Color kVyomaBubble, Color kVyomaBorder) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kVyomaBubble,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kVyomaBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAiVyomaHeaderRow(),
            if (vm.streamingText.isNotEmpty)
              Text(
                vm.streamingText,
                style: GoogleFonts.inter(
                  color: VyomaColors.textPrimary.withValues(alpha: 0.92),
                  fontSize: 14.5,
                  height: 1.6,
                ),
              ),
            const SizedBox(height: 8),
            const _TypingDotsPulse(),
          ],
        ),
      ),
    );
  }

  Widget _buildThinkingBubble(Color kVyomaBubble, Color kVyomaBorder, Color kAccent) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kVyomaBubble,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kVyomaBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: kAccent.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'thinking...',
              style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Refined palette
    const kSurface = Color(0xFF0A0D0F);
    const kVyomaBubble = Color(0xFF0C1214);
    final kVyomaBorder = const Color(0xFF059669).withValues(alpha: 0.15);
    const kAccent = Color(0xFF10B981);
    const kAccentDim = Color(0xFF059669);
    final bubbleMaxWidth = math.min(MediaQuery.of(context).size.width * 0.82, 860.0);

    return DropTarget(
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      onDragDone: (details) async {
        setState(() {
          _isDragging = false;
        });
        if (details.files.isNotEmpty) {
          final vm = context.read<WarRoomViewModel>();
          final file = details.files.first;
          final bytes = await file.readAsBytes();
          if (mounted) {
            vm.selectImage(bytes);
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: kSurface,
            body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(
                color: kSurface,
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton(
                     icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20),
                     onPressed: () => Navigator.pop(context),
                   ),
                   SvgPicture.asset(
                     'vyoma-icon-192.svg',
                     width: 18,
                     height: 18,
                   ),
                   // Status Indicators
                   Consumer<WarRoomViewModel>(
                     builder: (context, vm, _) {
                       if (vm.isSavingMemory) {
                          return const Tooltip(
                            message: "Saving Memory",
                            child: Icon(Icons.circle, color: Colors.orangeAccent, size: 8),
                          );
                       }
                       if (vm.isSyncing) {
                          return const Tooltip(
                            message: "Syncing Data",
                            child: Icon(Icons.circle, color: Colors.blueAccent, size: 8),
                          );
                       }
                       return const SizedBox(width: 8);
                     }
                   ),
                   Consumer<WarRoomViewModel>(
                    builder: (context, vm, _) => Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.undo_rounded, color: Colors.white54, size: 22),
                          tooltip: "Undo last AI action",
                          onPressed: vm.canUndo ? () => vm.undoLastAction() : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white54, size: 24),
                          tooltip: "History",
                          onPressed: () {
                             showModalBottomSheet(
                               context: context, 
                               backgroundColor: const Color(0xFF111518),
                               shape: const RoundedRectangleBorder(
                                 borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                               ),
                               builder: (_) => SizedBox(
                                 height: 400,
                                 child: Column(
                                   children: [
                                     Container(
                                       width: 40,
                                       height: 4,
                                       margin: const EdgeInsets.only(top: 12, bottom: 16),
                                       decoration: BoxDecoration(
                                         color: Colors.white24,
                                         borderRadius: BorderRadius.circular(2),
                                       ),
                                     ),
                                     Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                        child: Text("Mission Log", style: GoogleFonts.jetBrainsMono(color: Colors.white70, fontSize: 14, letterSpacing: 1.5)),
                                     ),
                                     const SizedBox(height: 12),
                                     Expanded(
                                       child: ListView.builder(
                                         itemCount: vm.sessions.length,
                                         itemBuilder: (ctx, i) {
                                           final session = vm.sessions[i];
                                           final isSelected = session.id == vm.currentSessionId;
                                           return ListTile(
                                             title: Text(session.title, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
                                             subtitle: Text(session.createdAt.toString().substring(0, 16), style: const TextStyle(color: Colors.white24, fontSize: 12)),
                                             tileColor: isSelected ? Colors.white.withValues(alpha: 0.05) : null,
                                             trailing: IconButton(
                                               icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                               onPressed: () {
                                                  vm.deleteSession(session.id);
                                                  Navigator.pop(ctx);
                                               },
                                             ),
                                             onTap: () {
                                               vm.loadSession(session.id);
                                               Navigator.pop(ctx);
                                             },
                                           );
                                         }
                                       ),
                                     ),
                                   ],
                                 ),
                               )
                             );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_comment_rounded, color: Colors.white54, size: 20),
                          tooltip: "New Chat",
                          onPressed: () => vm.startNewSession(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Chat list + inline error banner overlay
            Expanded(
              child: Consumer<WarRoomViewModel>(
                builder: (context, vm, _) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  final isFresh = vm.messages.where((m) => m.sender == 'USER').isEmpty;
                  final blocks = _chatBlocksFromMessages(vm.messages);

                  final messageChildren = <Widget>[
                    for (final b in blocks)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: switch (b) {
                          _BlkSys(:final msg) => _buildSystemLine(msg, kAccentDim),
                          _BlkGrp(:final sender, :final msgs) => _buildGroupBubbleColumn(
                              context: context,
                              sender: sender,
                              msgs: msgs,
                              bubbleMaxWidth: bubbleMaxWidth,
                              kAccent: kAccent,
                            ),
                        },
                      ),
                    if (vm.isStreaming)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildStreamingBubble(context, vm, kVyomaBubble, kVyomaBorder),
                      )
                    else if (vm.isProcessing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildThinkingBubble(kVyomaBubble, kVyomaBorder, kAccent),
                      ),
                    if (isFresh)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildTacticalSuggestions(vm),
                      ),
                  ];

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
                          children: messageChildren,
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildErrorBannerStrip(vm),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Slash Command Autocomplete + Input Area
            Consumer<WarRoomViewModel>(
              builder: (context, vm, _) => Padding(
                padding: EdgeInsets.fromLTRB(
                  12, 
                  0, 
                  12, 
                  MediaQuery.of(context).viewInsets.bottom + 12
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Builder(
                      builder: (context) {
                        final pending = vm.pendingDecision?.pendingConfirmations ?? [];
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.2),
                                end: Offset.zero,
                              ).animate(anim),
                              child: FadeTransition(opacity: anim, child: child),
                            );
                          },
                          child: pending.isEmpty
                              ? const SizedBox.shrink(key: ValueKey<String>('pending_none'))
                              : Padding(
                                  key: ValueKey<int>(pending.length),
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: PendingActionCard(
                                    key: VyomaTutorialKeys.pendingActionCard,
                                    pendingActions: pending,
                                    onApprove: () => vm.submitCommand('go ahead'),
                                    onDeny: () => vm.denyPendingDecision(),
                                  ),
                                ),
                        );
                      },
                    ),
                    // Slash Command Suggestions Overlay
                    if (_showCommandSuggestions)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 260),
                        margin: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF111518),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 24,
                              offset: const Offset(0, -8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: _filteredCommands.length,
                            itemBuilder: (context, index) {
                              final entry = _filteredCommands[index];
                              final cmd = entry.key;
                              final desc = entry.value[0];

                              return Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () => _selectCommand(cmd),
                                  splashColor: kAccent.withValues(alpha: 0.08),
                                  highlightColor: Colors.white.withValues(alpha: 0.03),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    child: Row(
                                      children: [
                                        // Command icon
                                        Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                            color: kAccent.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Icon(
                                            _commandIcon(cmd),
                                            color: kAccent.withValues(alpha: 0.7),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Command name + description
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                cmd,
                                                style: GoogleFonts.jetBrainsMono(
                                                  color: kAccent,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                desc,
                                                style: GoogleFonts.inter(
                                                  color: Colors.white38,
                                                  fontSize: 11.5,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Keyboard shortcut hint
                                        Icon(
                                          Icons.keyboard_return_rounded,
                                          color: Colors.white12,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // Image Preview Area
                    if (vm.selectedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, left: 48),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                vm.selectedImageBytes!,
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => vm.selectImage(null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Input Row
                    Container(
                      key: VyomaTutorialKeys.chatInputBar,
                      decoration: BoxDecoration(
                        color: const Color(0xFF141A1E),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: _showCommandSuggestions 
                              ? kAccent.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Image Button
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: IconButton(
                              icon: Icon(
                                vm.selectedImageBytes != null ? Icons.image : Icons.add_photo_alternate_outlined, 
                                color: vm.selectedImageBytes != null ? Colors.white : Colors.white24,
                                size: 22,
                              ),
                              onPressed: () async {
                                if (vm.isProcessing) return; 
                                if (vm.selectedImageBytes != null) {
                                  vm.selectImage(null); 
                                } else {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                    imageQuality: 70,
                                  );
                                  if (image != null) {
                                    final bytes = await image.readAsBytes();
                                    vm.selectImage(bytes);
                                  }
                                }
                              },
                            ),
                          ),
              
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              enabled: !vm.isProcessing, 
                              autocorrect: false,
                              enableSuggestions: false,
                              smartDashesType: SmartDashesType.disabled,
                              smartQuotesType: SmartQuotesType.disabled,
                              keyboardType: TextInputType.visiblePassword,
                              obscureText: false,
                              spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
                              decoration: InputDecoration(
                                hintText: vm.isProcessing 
                                   ? "Processing..." 
                                   : (vm.selectedImageBytes != null 
                                       ? "Add caption..." 
                                       : "Message Vyoma or type /"),
                                hintStyle: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.2), fontSize: 15),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                              ),
                              onSubmitted: (val) {
                                if (!vm.isProcessing) {
                                  vm.submitCommand(val);
                                  _controller.clear(); 
                                  _focusNode.requestFocus();
                                }
                              },
                            ),
                          ),
                          
                          const SizedBox(width: 4),
                          
                          // Send Button
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: _AnimatedSendButton(
                              isProcessing: vm.isProcessing,
                              onTap: () {
                                 if (vm.isProcessing) {
                                    vm.cancelRequest(); 
                                 } else {
                                    if (_controller.text.isNotEmpty || vm.selectedImageBytes != null) {
                                       vm.submitCommand(_controller.text);
                                       _controller.clear();
                                    }
                                 }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          ),
          if (_isDragging)
            Positioned.fill(
              child: Container(
                color: kAccent.withValues(alpha: 0.1),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    decoration: BoxDecoration(
                      color: kSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kAccent.withValues(alpha: 0.3), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kAccent.withValues(alpha: 0.2),
                          blurRadius: 32,
                          spreadRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.upload_file_rounded, color: kAccent, size: 64),
                        const SizedBox(height: 16),
                        Text(
                          "Drop image to attach",
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTacticalSuggestions(WarRoomViewModel vm) {
    final suggestions = [
      {
        "icon": Icons.table_chart_outlined,
        "title": "BUILD DAILY GRID",
        "subtitle": "Full day schedule from wake time",
        "cmd": "Construct a full day schedule for me. Start from wake time."
      },
      {
        "icon": Icons.upload_file,
        "title": "SYNC TIMETABLE",
        "subtitle": "Upload & extract semester schedule",
        "cmd": "I am uploading my timetable image. Extract it."
      },
      {
        "icon": Icons.flag_outlined,
        "title": "SET OBJECTIVE",
        "subtitle": "Define your weekly goal",
        "cmd": "I need to define my Main Goal for this week."
      },
       {
        "icon": Icons.psychology_outlined,
        "title": "BRAINSTORM",
        "subtitle": "Strategy session for your project",
        "cmd": "Help me brainstorm a strategy for my project."
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Text(
              "QUICK ACTIONS",
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white.withValues(alpha: 0.2),
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ...suggestions.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  splashColor: const Color(0xFF10B981).withValues(alpha: 0.06),
                  onTap: () {
                    if (s['title'] == "SYNC TIMETABLE") {
                       vm.submitCommand("I want to upload my timetable image.");
                    } else {
                       vm.submitCommand(s['cmd'] as String);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111518),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(s['icon'] as IconData, color: const Color(0xFF10B981).withValues(alpha: 0.6), size: 18),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s['title'] as String,
                                style: GoogleFonts.inter(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                s['subtitle'] as String,
                                style: GoogleFonts.inter(
                                  color: Colors.white30,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios_rounded, color: Colors.white12, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          // Slash command hint
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Text(
                    "/",
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Type / for commands",
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.16),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Three-dot pulse while assistant streams tokens.
class _TypingDotsPulse extends StatefulWidget {
  const _TypingDotsPulse();

  @override
  State<_TypingDotsPulse> createState() => _TypingDotsPulseState();
}

class _TypingDotsPulseState extends State<_TypingDotsPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final v = ((_c.value + i * 0.2) % 1.0);
            final opacity = 0.35 + 0.55 * (math.sin(v * math.pi * 2) * 0.5 + 0.5);
            return Padding(
              padding: const EdgeInsets.only(right: 5),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: VyomaColors.accentBright.withValues(alpha: opacity),
                  boxShadow: [
                    BoxShadow(
                      color: VyomaColors.accentBright.withValues(alpha: opacity * 0.35),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Animated Send Button with hover and press effects
class _AnimatedSendButton extends StatefulWidget {
  final bool isProcessing;
  final VoidCallback onTap;

  const _AnimatedSendButton({
    required this.isProcessing,
    required this.onTap,
  });

  @override
  State<_AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<_AnimatedSendButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const kAccent = Color(0xFF10B981);
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.88 : (_isHovered ? 1.08 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: widget.isProcessing 
                  ? Colors.redAccent 
                  : (_isHovered ? kAccent : Colors.white),
              shape: BoxShape.circle,
              boxShadow: _isHovered ? [
                BoxShadow(
                  color: (widget.isProcessing ? Colors.redAccent : kAccent)
                      .withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ] : null,
            ),
            child: Icon(
              widget.isProcessing ? Icons.stop_rounded : Icons.arrow_upward_rounded, 
              color: _isHovered && !widget.isProcessing ? Colors.white : Colors.black, 
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact copy-to-clipboard button shown next to message timestamps.
/// Mirrors ChatGPT/Claude affordance: idle copy icon, briefly swaps to
/// a green check after the user taps.
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleCopy() async {
    if (widget.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.text));
    if (!mounted) return;
    setState(() => _copied = true);
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _copied
        ? const Color(0xFF10B981)
        : VyomaColors.textMuted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleCopy,
        child: Tooltip(
          message: _copied ? 'Copied' : 'Copy',
          waitDuration: const Duration(milliseconds: 400),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              key: ValueKey<bool>(_copied),
              size: 12,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
