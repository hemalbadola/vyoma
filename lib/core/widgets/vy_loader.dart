import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

// The bindu breathes while loading — not a spinner
class VyLoader extends StatefulWidget {
  const VyLoader({super.key});

  @override
  State<VyLoader> createState() => _VyLoaderState();
}

class _VyLoaderState extends State<VyLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: VyDuration.verySlow,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, _) => Opacity(
          opacity: _pulse.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: VyColors.gold,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
