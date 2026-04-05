import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/memory_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/background_mesh.dart';

class MemoryVaultScreen extends StatelessWidget {
  const MemoryVaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          const BackgroundMesh(),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 24),
                Expanded(
                  child: Consumer<MemoryService>(
                    builder: (context, memory, _) {
                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          _buildSlabTitle("✧ AI MEMORY CONTEXT"),
                          _buildSegmentToggles(context, memory),
                          const SizedBox(height: 32),

                          _buildSlabTitle("CORE IDENTITY"),
                          _buildIdentitySlab(context, memory),
                          const SizedBox(height: 32),
                          
                          _buildSlabTitle("AGENT RETENTION"),
                          _buildHistorySlab(context, memory),
                          const SizedBox(height: 32),

                          _buildSlabTitle("SYSTEM PREFS"),
                          _buildPrefsSlab(context, memory),
                          const SizedBox(height: 32),

                          _buildSlabTitle("SEMANTIC NEURAL NET (FACTS)"),
                          _buildFactsSlab(context, memory),
                          const SizedBox(height: 50),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("MNEMOSYNE", style: GoogleFonts.jetBrainsMono(color: Colors.white38, fontSize: 10, letterSpacing: 2)),
              Text("MEMORY VAULT", style: GoogleFonts.dmSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlabTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.jetBrainsMono(color: const Color(0xFF7C3AED), fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSegmentToggles(BuildContext context, MemoryService memory) {
    final toggles = memory.getSegmentToggles();
    
    final segmentLabels = {
      'identity': ('👤', 'Identity', 'Who you are'),
      'facts': ('🧠', 'Facts', 'Learned about you'),
      'preferences': ('⚙️', 'Preferences', 'Your settings'),
      'history': ('📜', 'History', 'Past interactions'),
      'protocol': ('🎯', 'Protocol', 'Goals & blockers'),
      'supermemory': ('✨', 'Supermemory', 'Long-term recall'),
    };

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Control which memories Vyoma can access:",
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...MemoryService.memoryCategories.map((segment) {
            final (icon, label, desc) = segmentLabels[segment] ?? ('📦', segment, '');
            final isEnabled = toggles[segment] ?? true;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text(icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                        Text(desc, style: GoogleFonts.inter(color: Colors.white38, fontSize: 10)),
                      ],
                    ),
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (val) => memory.toggleSegment(segment, val),
                    activeThumbColor: const Color(0xFF7C3AED),
                    inactiveTrackColor: Colors.white12,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildIdentitySlab(BuildContext context, MemoryService memory) {
    final identity = memory.getSegment('identity') as Map<String, dynamic>? ?? {};
    
    return GlassCard(
      child: Column(
        children: [
          _buildEditableField(context, "ROLE", identity['role'] ?? "Unknown", (val) {
             memory.updateIdentity(val, identity['institution'] ?? "");
          }),
          Divider(color: Colors.white12),
          _buildEditableField(context, "AFFILIATION", identity['institution'] ?? "Unknown", (val) {
             memory.updateIdentity(identity['role'] ?? "", val);
          }),
        ],
      ),
    );
  }

  Widget _buildHistorySlab(BuildContext context, MemoryService memory) {
    final logs = memory.getAllLogs(); // This is reversed in our service method
    final recentLogs = logs.take(5).toList();
    
    if (logs.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text("NO ENGRAMS FOUND", style: GoogleFonts.jetBrainsMono(color: Colors.white24))),
      );
    }

    return Column(
      children: [
        ...recentLogs.asMap().entries.map((entry) {
            final index = entry.key;
            final log = entry.value;
            // Note: Indexing for delete needs to match the REAL list. 
            // Since getAllLogs() returns REVERSED, the real index is (length - 1 - index).
            final realIndex = (memory.getSegment('agent_history') as List).length - 1 - index;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(log.timestamp.toString()),
                background: Container(color: Colors.red.withValues(alpha: 0.2), alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 16), child: Icon(Icons.delete, color: Colors.red)),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  memory.deleteLog(realIndex);
                },
                child: GlassCard(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  child: Row(
                    children: [
                      Text(
                        DateFormat('MM/dd').format(log.timestamp),
                        style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(log.actionType, style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      ),
                      Text(
                        log.outcome,
                        style: GoogleFonts.jetBrainsMono(color: log.outcome == 'Success' ? Colors.greenAccent : Colors.redAccent, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            );
        }),
        if (logs.length > 5)
           Center(child: Text("+ ${logs.length - 5} MORE ARCHIVED", style: GoogleFonts.jetBrainsMono(color: Colors.white24, fontSize: 10))),
      ],
    );
  }

  Widget _buildFactsSlab(BuildContext context, MemoryService memory) {
    final facts = memory.getFacts();

    if (facts.isEmpty) {
      return GlassCard(
         padding: const EdgeInsets.all(24),
         child: Center(child: Text("NO DATA ENCODED", style: GoogleFonts.jetBrainsMono(color: Colors.white24))),
      );
    }

    return Column(
      children: facts.entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: ValueKey("fact_${e.key}"),
            direction: DismissDirection.endToStart,
            background: Container(color: Colors.red.withValues(alpha: 0.2), alignment: Alignment.centerRight, padding: EdgeInsets.only(right: 16), child: Icon(Icons.delete, color: Colors.red)),
            onDismissed: (_) {
               memory.forgetFact(e.key);
            },
            child: GlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 12,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text(e.key.toUpperCase(), style: GoogleFonts.jetBrainsMono(color: const Color(0xFF00FF9C), fontSize: 10)),
                         const SizedBox(height: 4),
                         Text(e.value.toString(), style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white24, size: 20),
                    onPressed: () {
                       memory.forgetFact(e.key);
                    },
                  )
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrefsSlab(BuildContext context, MemoryService memory) {
    final prefs = memory.getSegment('preferences') as Map<String, dynamic>? ?? {};
    return GlassCard(
       child: Column(
         children: prefs.entries.map((e) {
           return _buildEditableField(context, e.key.toUpperCase(), e.value.toString(), (val) {
              final newPrefs = Map<String, dynamic>.from(prefs);
              newPrefs[e.key] = val;
              memory.updateSegment('preferences', newPrefs);
           });
         }).toList(),
       ),
    );
  }

  Widget _buildEditableField(BuildContext context, String label, String value, Function(String) onSave) {
    return InkWell(
      onTap: () {
        _showEditDialog(context, label, value, onSave);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12)),
            Row(
              children: [
                Text(value, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 12, color: Colors.white24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, String label, String currentValue, Function(String) onSave) {
    final controller = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: Text("EDIT $label", style: GoogleFonts.dmSans(color: Colors.white)),
        content: TextField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          keyboardType: TextInputType.visiblePassword,
          obscureText: false,
          spellCheckConfiguration: SpellCheckConfiguration.disabled(),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("CANCEL", style: TextStyle(color: Colors.white54))
          ),
          TextButton(
            onPressed: () {
              onSave(controller.text);
              Navigator.pop(ctx);
            }, 
            child: const Text("SAVE", style: TextStyle(color: Colors.white))
          ),
        ],
      )
    );
  }
}
