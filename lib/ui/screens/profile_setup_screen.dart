import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/user_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/vy_loader.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _taglineController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() => _error = "Username must be at least 3 chars.");
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final userSvc = context.read<UserService>();

    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        await auth.signInAnonymously();
      }

      final isAvailable = await userSvc.isUsernameAvailable(username);
      if (!isAvailable) {
        setState(() {
          _error = "Agent designation taken. Try another.";
          _isLoading = false;
        });
        return;
      }

      await userSvc.createProfile(
        username: username,
        tagline: _taglineController.text.trim(),
      );
      
      // Wait for stream to update UI automatically
    } on FirebaseAuthException catch (e) {
      final raw = '${e.code} ${e.message ?? ''}'.toLowerCase();
      final keychainIssue = raw.contains('keychain');
      setState(() {
        _error = keychainIssue
            ? 'Secure keychain access blocked on this device. Complete onboarding and continue in local mode, then reconnect Firebase later from Settings.'
            : e.toString();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "INITIALIZE AGENT",
                style: GoogleFonts.jetBrainsMono(
                  color: AppColors.gold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Declare your unique designation within the Vyoma Node.",
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _usernameController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'AGENT USERNAME',
                  labelStyle: const TextStyle(color: AppColors.gold),
                  prefixText: '@ ',
                  prefixStyle: const TextStyle(color: Colors.white54),
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _taglineController,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'CURRENT DIRECTIVE (TAGLINE)',
                  labelStyle: TextStyle(color: Colors.white54),
                  hintText: 'e.g. Building Next-Gen Systems',
                  hintStyle: TextStyle(color: Colors.white24),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white24),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
              ],
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C3AED),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading 
                    ? const VyLoader()
                    : Text(
                        "ENTER THE CIRCLE", 
                        style: GoogleFonts.inter(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
