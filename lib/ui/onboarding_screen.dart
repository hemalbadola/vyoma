import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/memory_service.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _textController = TextEditingController();
  int _currentStep = 0;

  // Data to collect (streamlined to 3 core questions)
  String _wakeTime = "";
  String _mainGoal = "";
  String _blocker = "";
  
  void _nextStep() {
    if (_textController.text.isEmpty) return;

    final text = _textController.text;

    // Save Data based on step (3 questions)
    switch (_currentStep) {
      case 0: _wakeTime = text; break;
      case 1: _mainGoal = text; break;
      case 2: 
        _blocker = text;
        _finishOnboarding();
        return;
    }

    _textController.clear();
    _pageController.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
    setState(() => _currentStep++);
  }

  Future<void> _finishOnboarding() async {
    final memory = Provider.of<MemoryService>(context, listen: false);
    
    // Only save core data; rest learned through conversation
    await memory.updateRoutine(_wakeTime, "23:00"); // Default sleep time
    await memory.updateProtocol(_mainGoal, _blocker);

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // Progress (3 steps now)
            LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              color: const Color(0xFF10B981), // Emerald
              backgroundColor: const Color(0xFF1F1F2E),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                   _buildQuestion("STARTING POINT", "What time do you usually wake up? (e.g. 07:00)"),
                   _buildQuestion("YOUR FOCUS", "What's the one thing you want to accomplish right now?"),
                   _buildQuestion("THE BLOCKER", "What usually gets in the way?"),
                ],
              ),
            ),

            // Input
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 18),
                      decoration: InputDecoration(
                        hintText: "Type response...",
                        hintStyle: GoogleFonts.inter(color: Colors.white24),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3F3F5C))),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF7C3AED))),
                      ),
                      onSubmitted: (_) => _nextStep(),
                      autofocus: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward, color: Color(0xFF7C3AED)),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(String overline, String question) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            overline, 
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF8E8E93), fontSize: 12, letterSpacing: 2)
          ),
          const SizedBox(height: 16),
          Text(
            question,
            style: GoogleFonts.dmSans(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, height: 1.1),
          ),
        ],
      ),
    );
  }
}
