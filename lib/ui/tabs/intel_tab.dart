import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../war_room_viewmodel.dart';
import '../../core/memory_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../ui/widgets/glass_card.dart';
import '../screens/memory_vault_screen.dart';

class IntelTab extends StatelessWidget {
  const IntelTab({super.key});

  // High Contrast Palette
  static const kCardBg = Color(0xFF121212);
  static const kBorder = Color(0xFF2A2A2A);
  static const kBurgundy = Color(0xFFB91C32);
  static const kEmerald = Color(0xFF10B981);
  static const kEmeraldLight = Color(0xFF34D399);
  static const kGold = Color(0xFFE5C158);
  static const kTextPrimary = Color(0xFFFFFFFF);
  static const kTextSecondary = Color(0xFFA3A3A3);
  static const kTextMuted = Color(0xFF737373);

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<WarRoomViewModel>(context);
    final metrics = vm.currentMetrics;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            "INTEL",
            style: GoogleFonts.inter(
              color: kTextMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your metrics",
            style: GoogleFonts.dmSans(
              color: kTextPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 32),

          // Main Stats Grid
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  symbol: "◈",
                  label: "FOCUS",
                  value: "${(metrics.focusMinutes / 60).toStringAsFixed(1)}h",
                  color: kEmerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  symbol: "▣",
                  label: "TASKS",
                  value: "${metrics.tasksCompleted}",
                  color: kEmeraldLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  symbol: "◇",
                  label: "DISTRACTIONS",
                  value: "${metrics.distractionCount}",
                  color: kBurgundy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  symbol: "◎",
                  label: "SESSIONS",
                  value: "1",
                  color: kGold,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Activity Log Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ACTIVITY",
                style: GoogleFonts.inter(
                  color: kTextMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.0,
                ),
              ),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MemoryVaultScreen()),
                  ),
                  child: Text(
                    "MEMORIES →",
                    style: GoogleFonts.inter(
                      color: kTextSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Activity Log
          Consumer<MemoryService>(
            builder: (context, memory, _) {
              final logs = memory.getAllLogs();
              if (logs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder, width: 0.5),
                  ),
                  child: Center(
                    child: Text(
                      "No activity yet",
                      style: GoogleFonts.inter(color: kTextMuted, fontSize: 13),
                    ),
                  ),
                );
              }

              return Column(
                children: logs.take(10).toList().asMap().entries.map((e) {
                  final i = e.key;
                  final log = e.value;
                  final isSuccess = log.outcome == "Success";
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildActivityItem(
                      log.actionType,
                      DateFormat('MM/dd HH:mm').format(log.timestamp),
                      log.energyImpact,
                      isSuccess,
                    ),
                  ).animate(delay: (50 * i).ms).fadeIn().slideX(begin: 0.05);
                }).toList(),
              );
            }
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String symbol,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: GoogleFonts.inter(color: color, fontSize: 14),
                  ),
                ),
              ),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: kTextMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: kTextPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String action, String time, int impact, bool isSuccess) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess ? kEmerald.withOpacity(0.15) : kBurgundy.withOpacity(0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Text(
            isSuccess ? "◈" : "◇",
            style: GoogleFonts.inter(
              color: isSuccess ? kEmeraldLight : kBurgundy,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: kTextPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: GoogleFonts.inter(
                    color: kTextMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "${impact > 0 ? '+' : ''}$impact",
            style: GoogleFonts.jetBrainsMono(
              color: impact > 0 ? kEmeraldLight : kBurgundy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
