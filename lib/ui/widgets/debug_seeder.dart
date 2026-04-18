import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/user_service.dart';

class DebugSeeder extends StatefulWidget {
  const DebugSeeder({super.key});

  @override
  State<DebugSeeder> createState() => _DebugSeederState();
}

class _DebugSeederState extends State<DebugSeeder> {
  bool _isSeeding = false;

  Future<void> _seedDatabase() async {
    final userSvc = context.read<UserService>();
    final myUid = userSvc.currentProfile?.uid;
    if (myUid == null) return;

    setState(() => _isSeeding = true);
    
    try {
      final db = FirebaseFirestore.instance;
      final batch = db.batch();

      // Mocks
      final mocks = [
        {'uid': 'mock_priya', 'username': 'priya_dev', 'name': 'Priya', 'tag': 'Designing standard'},
        {'uid': 'mock_arjun', 'username': 'arjun_code', 'name': 'Arjun', 'tag': 'Shipping v2'},
        {'uid': 'mock_sam', 'username': 'sam_builds', 'name': 'Sam', 'tag': 'Deep Learning'},
      ];

      for (int index = 0; index < mocks.length; index++) {
        var mock = mocks[index];
        // Create Mock User
        final userRef = db.collection('users').doc(mock['uid']!);
        batch.set(userRef, {
          'uid': mock['uid'],
          'username': mock['username'],
          'displayName': mock['name'],
          'tagline': mock['tag'],
          'currentIntention': 'Stay focused on the mission',
          'intentionSetAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'timezone': 'UTC',
          'activeTasks': [
            'Finalize UI Redesign v2',
            'Debug Firebase permissions',
            'Deploy to TestFlight'
          ],
          'lastSeenAt': index == 0 
            ? FieldValue.serverTimestamp() 
            : Timestamp.fromDate(DateTime.now().subtract(Duration(hours: index + 1))),
        });

        // Generate Friendship (bidirectional)
        final friendshipRef1 = db.collection('friendships').doc('${myUid}_${mock['uid']}');
        batch.set(friendshipRef1, {
          'user1': myUid,
          'user2': mock['uid'],
          'establishedAt': FieldValue.serverTimestamp(),
        });
        final friendshipRef2 = db.collection('friendships').doc('${mock['uid']}_$myUid');
        batch.set(friendshipRef2, {
          'user1': mock['uid'],
          'user2': myUid,
          'establishedAt': FieldValue.serverTimestamp(),
        });

        // Give them random activities over past 7 days
        for (int i = 0; i < 5; i++) {
          final actRef = db.collection('activities').doc();
          batch.set(actRef, {
            'userId': mock['uid'],
            'type': 'task_completed',
            'durationMinutes': 0,
            'points': 10,
            'visibility': 'public',
            'timestamp': DateTime.now().subtract(Duration(days: i)),
          });
          
          final fSessionRef = db.collection('activities').doc();
          batch.set(fSessionRef, {
            'userId': mock['uid'],
            'type': 'focus_session',
            'durationMinutes': 45 + (i * 10),
            'points': 45 + (i * 10),
            'visibility': 'public',
            'timestamp': DateTime.now().subtract(Duration(days: i, hours: 2)),
          });
        }
      }

      // Create an active pact involving the user and priya
      final pactRef = db.collection('pacts').doc('mock_pact_123');
      batch.set(pactRef, {
        'creatorUid': 'mock_priya',
        'title': 'Deep Work Sync',
        'targetMinutes': 60,
        'deadline': DateTime.now().add(const Duration(minutes: 60)),
        'status': 'active', // Forces it into active strip
        'participants': ['mock_priya', myUid],
        'visibleTo': [myUid],
        'completedBy': [],
        'failedBy': [],
        'createdAt': FieldValue.serverTimestamp()
      });

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Firebase Sandbox Seeded with 3 Agents.'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed failed: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink(); // Hide in prod

    return FloatingActionButton.extended(
      backgroundColor: Colors.amber,
      onPressed: _isSeeding ? null : _seedDatabase,
      icon: _isSeeding 
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : const Icon(Icons.bug_report, color: Colors.black, size: 18),
      label: Text(
        _isSeeding ? "SEEDING..." : "SEED DB",
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
