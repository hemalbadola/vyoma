import 'package:flutter/material.dart';
import '../theme/vyoma_tokens.dart';

class VySectionLabel extends StatelessWidget {
  final String text;
  const VySectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: VyType.sectionLabel);
  }
}
