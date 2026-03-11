import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../war_room_viewmodel.dart';

class ChatSheet extends StatefulWidget {
  const ChatSheet({super.key});

  @override
  State<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends State<ChatSheet> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Premium Palette
    final kUserBubble = const Color(0xFF0D0D0D);
    final kVyomaBubble = const Color(0xFF080808);
    final kVyomaBorder = const Color(0xFF059669).withOpacity(0.2);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   IconButton(
                     icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20),
                     onPressed: () => Navigator.pop(context),
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
                          icon: const Icon(Icons.history, color: Colors.white54, size: 24),
                          tooltip: "History",
                          onPressed: () {
                             showModalBottomSheet(
                               context: context, 
                               backgroundColor: Colors.grey[900],
                               builder: (_) => SizedBox(
                                 height: 400,
                                 child: Column(
                                   children: [
                                     Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Text("Mission Log", style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 16)),
                                     ),
                                     Expanded(
                                       child: ListView.builder(
                                         itemCount: vm.sessions.length,
                                         itemBuilder: (ctx, i) {
                                           final session = vm.sessions[i];
                                           final isSelected = session.id == vm.currentSessionId;
                                           return ListTile(
                                             title: Text(session.title, style: GoogleFonts.inter(color: isSelected ? Colors.white : Colors.white70)),
                                             subtitle: Text(session.createdAt.toString().substring(0, 16), style: TextStyle(color: Colors.white24, fontSize: 12)),
                                             tileColor: isSelected ? Colors.white10 : null,
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
            
            // Chat List or Suggestions
            Expanded(
              child: Consumer<WarRoomViewModel>(
                builder: (context, vm, child) {
                  WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                  // Show Suggestions if only system messages exist or empty
                  final isFresh = vm.messages.where((m) => m.sender == 'USER').isEmpty;

                  return Stack(
                    children: [
                      ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                        itemCount: vm.messages.length + (vm.isProcessing ? 1 : 0) + (isFresh ? 1 : 0), // Use +1 for suggestions spacer
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          if (isFresh && index == vm.messages.length) {
                             return _buildTacticalSuggestions(vm);
                          }
                          
                          if (index >= vm.messages.length) {
                             // Processing Indicator
                             return Align(
                               alignment: Alignment.centerLeft,
                               child: Container(
                                 padding: const EdgeInsets.all(12),
                                 decoration: BoxDecoration(
                                   color: kVyomaBubble,
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(color: kVyomaBorder),
                                 ),
                                 child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
                               ),
                             );
                          }

                          final msg = vm.messages[index];
                          final isUser = msg.sender == 'USER';

                          return Align(
                            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onLongPress: () {
                                 // Clipboard.setData(ClipboardData(text: msg.text));
                              },
                              child: Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isUser ? kUserBubble : kVyomaBubble,
                                  borderRadius: BorderRadius.circular(18),
                                  border: isUser ? null : Border.all(color: kVyomaBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (msg.imageBytes != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.memory(
                                            msg.imageBytes!,
                                            fit: BoxFit.cover,
                                            height: 150,
                                          ),
                                        ),
                                      ),
                                    SelectableText( 
                                      msg.text,
                                      style: isUser 
                                         ? GoogleFonts.inter(color: Colors.white, fontSize: 15)
                                         : GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13, height: 1.4), 
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Input Area
            Consumer<WarRoomViewModel>(
              builder: (context, vm, _) => Padding(
                padding: EdgeInsets.fromLTRB(
                  16, 
                  8, 
                  16, 
                  MediaQuery.of(context).viewInsets.bottom + 16
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image Preview Area
                    if (vm.selectedImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12, left: 48),
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
                    Row(
                      children: [
                        // Image Button
                        IconButton(
                          icon: Icon(
                            vm.selectedImageBytes != null ? Icons.image : Icons.add_photo_alternate_outlined, 
                            color: vm.selectedImageBytes != null ? Colors.white : Colors.white24
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
                        const SizedBox(width: 8),
    
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1C1C1E),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              enabled: !vm.isProcessing, 
                              style: GoogleFonts.inter(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: vm.isProcessing 
                                   ? "Transmitting..." 
                                   : (vm.selectedImageBytes != null ? "Add caption..." : "Enter command..."),
                                hintStyle: GoogleFonts.inter(color: Colors.white24),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Dynamic Action Button (Stop or Send) with animation
                        _AnimatedSendButton(
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalSuggestions(WarRoomViewModel vm) {
    final suggestions = [
      {
        "icon": Icons.table_chart_outlined,
        "title": "BUILD DAILY GRID",
        "cmd": "Construct a full day schedule for me. Start from wake time."
      },
      {
        "icon": Icons.upload_file,
        "title": "SYNC TIMETABLE",
        "cmd": "I am uploading my semester timetable. Extract it."
      },
      {
        "icon": Icons.flag_outlined,
        "title": "SET PRIME OBJECTIVE",
        "cmd": "I need to define my Main Goal for this week."
      },
       {
        "icon": Icons.psychology_outlined,
        "title": "BRAINSTORM",
        "cmd": "Help me brainstorm a strategy for my project."
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("TACTICAL DIRECTIVES", style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: suggestions.map((s) {
              return ActionChip(
                backgroundColor: const Color(0xFF1C1C1E),
                padding: const EdgeInsets.all(12),
                avatar: Icon(s['icon'] as IconData, color: Colors.white54, size: 18),
                label: Text(s['title'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                onPressed: () {
                  if (s['title'] == "SYNC TIMETABLE") {
                     // Just hint user to upload
                     vm.submitCommand("I want to upload my timetable image.");
                  } else {
                     vm.submitCommand(s['cmd'] as String);
                  }
                },
                side: const BorderSide(color: Colors.white10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              );
            }).toList(),
          ),
        ],
      ),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: widget.isProcessing 
                  ? Colors.redAccent 
                  : (_isHovered ? const Color(0xFF10B981) : Colors.white),
              shape: BoxShape.circle,
              boxShadow: _isHovered ? [
                BoxShadow(
                  color: (widget.isProcessing ? Colors.redAccent : const Color(0xFF10B981))
                      .withOpacity(0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ] : null,
            ),
            child: Icon(
              widget.isProcessing ? Icons.stop : Icons.arrow_upward, 
              color: _isHovered && !widget.isProcessing ? Colors.white : Colors.black, 
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
