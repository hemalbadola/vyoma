import 'package:flutter/widgets.dart';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefDir = Directory('${Platform.environment['HOME']}/Library/Containers/com.example.vyoma/Data/Library/Preferences/');
  if (!prefDir.existsSync()) {
    debugPrint('Cannot find macOS SharedPreferences directory.');
    return;
  }
  
  final file = File('${prefDir.path}/com.example.vyoma.plist');
  if (file.existsSync()) {
    debugPrint('Found preferences file: ${file.path}');
    final content = file.readAsStringSync();
    debugPrint('Content excerpts:');
    for (var line in content.split('\n')) {
      if (line.contains('vyoma_timetable')) {
        debugPrint(line);
      }
    }
  } else {
    debugPrint('No plist found.');
  }
}
