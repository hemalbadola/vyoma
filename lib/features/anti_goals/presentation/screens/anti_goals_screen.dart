import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/vyoma_tokens.dart' show VyType;
import '../../domain/anti_goals_service.dart';

class AntiGoalsScreen extends StatefulWidget {
  const AntiGoalsScreen({super.key});

  @override
  State<AntiGoalsScreen> createState() => _AntiGoalsScreenState();
}

class _AntiGoalsScreenState extends State<AntiGoalsScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await context.read<AntiGoalsService>().add(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<AntiGoalsService>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: const BackButton(color: AppColors.textPrimary),
        title: Text('anti-goals', style: VyType.heading),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'name what you refuse to become.\n'
                'this list is sharper than your goals.',
                style: VyType.bodyMuted.copyWith(height: 1.6),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: VyType.body,
                      onSubmitted: (_) => _add(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'someone who confuses busyness with purpose',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _add,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (svc.items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'nothing yet.',
                    style: VyType.bodyMuted,
                  ),
                )
              else
                ...List.generate(svc.items.length, (i) {
                  final item = svc.items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 12, top: 6),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppColors.errorColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item,
                              style: VyType.body,
                            ),
                          ),
                          IconButton(
                            onPressed: () =>
                                context.read<AntiGoalsService>().remove(i),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textMuted,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
