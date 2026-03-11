
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/ai_service.dart';
import '../../core/secrets.dart';

class ApiKeyManager extends StatelessWidget {
  const ApiKeyManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: Colors.white24),
      ),
      child: Consumer<AIService>(
        builder: (context, aiService, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "API KEY COMMAND CENTER",
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.cyanAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24),
              const SizedBox(height: 10),

              // Keys Grid
              Text(
                "SELECT ACTIVE GEMINI KEY:",
                style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Expanded(
                flex: 2,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: Secrets.geminiApiKeys.length,
                  itemBuilder: (context, index) {
                    final key = Secrets.geminiApiKeys[index];
                    final isActive = aiService.currentGeminiIndex == index;
                    final status = aiService.keyStates[index] ?? "UNK";
                    
                    Color statusColor = Colors.grey;
                    if (status == "OK") statusColor = Colors.greenAccent;
                    else if (status == "429") statusColor = Colors.orangeAccent;
                    else if (status == "EXPIRED") statusColor = Colors.redAccent;
                    else if (status == "TIMEOUT") statusColor = Colors.yellowAccent;
                    else if (status == "ERR") statusColor = Colors.red;

                    return InkWell(
                      onTap: () {
                        aiService.setManualGeminiKey(index);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Switched to Key ${index + 1}"),
                            duration: const Duration(milliseconds: 500),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? Colors.cyan.withOpacity(0.2) : Colors.black45,
                          border: Border.all(
                            color: isActive ? Colors.cyanAccent : statusColor.withOpacity(0.5),
                            width: isActive ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "KEY ${index + 1}",
                              style: GoogleFonts.jetBrainsMono(
                                color: isActive ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                status,
                                style: GoogleFonts.jetBrainsMono(
                                  color: statusColor,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 8),

              // Logs Console
              Text(
                "SYSTEM LOGS:",
                style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(color: Colors.white12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    reverse: true, // Show latest at bottom? No, reverse:true shows item 0 at bottom.
                    // My logs list appends to end. So index 0 is old.
                    // I want logging style (newest at bottom).
                    // If I use reverse:true, item 0 is at bottom.
                    // If my list has [Old, New], item 0 is Old.
                    // So reverse:true would put Old at bottom.
                    // I should reverse the list or use reverse:false and scroll to end.
                    // Or just render in reverse order: logs.reversed.toList()
                    itemCount: aiService.logs.length,
                    itemBuilder: (context, index) {
                      // Show newest first at top? Or console style?
                      // Console style: Newest at bottom.
                      // Let's just show newest at TOP for easier reading on mobile.
                      final log = aiService.logs[aiService.logs.length - 1 - index];
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: GoogleFonts.firaCode(
                            color: Colors.greenAccent,
                            fontSize: 10,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
