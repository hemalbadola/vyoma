import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class WakeupScreen extends StatefulWidget {
  final VoidCallback onWakeupConfirmed;

  const WakeupScreen({super.key, required this.onWakeupConfirmed});

  @override
  State<WakeupScreen> createState() => _WakeupScreenState();
}

class _WakeupScreenState extends State<WakeupScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _controller = TextEditingController();
  
  late String _challengeQuote;
  late int _mathA;
  late int _mathB;
  bool _isMathChallenge = true; // Randomize later if needed
  
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _startAlarm();
    _generateChallenge();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startAlarm() async {
    // Play a harsh sine wave or similar if asset not available, 
    // OR just use system sound logic if possible.
    // Since we don't have assets guaranteed, we'll try to play a default 'Ping' or silence + aggressive visuals.
    // Ideally we would load a 'siren.mp3' from assets.
    // For now, let's rely on VISUAL ALARM if no audio asset.
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // await _audioPlayer.play(AssetSource('sounds/alarm.mp3')); // Uncomment if asset added
  }

  void _generateChallenge() {
    final random = Random();
    // 50% chance of Math vs Quote
    _isMathChallenge = random.nextBool();

    if (_isMathChallenge) {
      _mathA = random.nextInt(15) + 5; // 5-20
      _mathB = random.nextInt(15) + 5;
    } else {
      final quotes = [
        "DISCIPLINE IS FREEDOM",
        "PAIN IS WEAKNESS LEAVING",
        "NO RETREAT NO SURRENDER",
        "EXECUTE THE MISSION"
      ];
      _challengeQuote = quotes[random.nextInt(quotes.length)];
    }
  }

  void _checkAnswer(String value) {
    bool correct = false;
    if (_isMathChallenge) {
      if (value.trim() == (_mathA * _mathB).toString()) correct = true; // Multiplication is harder
    } else {
      if (value.trim().toUpperCase() == _challengeQuote) correct = true;
    }

    if (correct) {
      _audioPlayer.stop();
      widget.onWakeupConfirmed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Stack(
        children: [
          // Flashing Background
          Container(
            color: Colors.black,
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .color(begin: Colors.black, end: const Color(0xFF220000), duration: 500.ms),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.redAccent),
                  const SizedBox(height: 20),
                  Text(
                    "WAKE UP PROTOCOL",
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.redAccent, letterSpacing: 4, fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Time
                  Text(
                    DateFormat('HH:mm').format(_now),
                    style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 80, fontWeight: FontWeight.w900
                    ),
                  ),

                  const SizedBox(height: 60),

                  // Challenge
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.redAccent)
                    ),
                    child: Column(
                      children: [
                        Text(
                          "PROVE CONSCIOUSNESS",
                          style: GoogleFonts.jetBrainsMono(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isMathChallenge ? "$_mathA  x  $_mathB  =  ?" : "TYPE: \"$_challengeQuote\"",
                          style: GoogleFonts.dmSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _controller,
                          autocorrect: false,
                          enableSuggestions: false,
                          smartDashesType: SmartDashesType.disabled,
                          smartQuotesType: SmartQuotesType.disabled,
                          // visiblePassword prevents NSSpellServer from registering
                          // even with autofocus=true; obscureText=false keeps text visible
                          keyboardType: _isMathChallenge ? TextInputType.number : TextInputType.visiblePassword,
                          obscureText: false,
                          spellCheckConfiguration: SpellCheckConfiguration.disabled(),
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: "ENTER ANSWER",
                            hintStyle: GoogleFonts.jetBrainsMono(color: Colors.white24),
                            border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                            enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                            focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                          ),
                          onChanged: _checkAnswer,
                          autofocus: true,
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
    );
  }
}
