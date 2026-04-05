import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefDir = Directory('${Platform.environment['HOME']}/Library/Containers/com.example.vyoma/Data/Library/Preferences/');
  if (!prefDir.existsSync()) {
    print("Cannot find macOS SharedPreferences directory.");
    return;
  }
  
  final file = File('${prefDir.path}/com.example.vyoma.plist');
  if (file.existsSync()) {
    print("Found preferences file: ${file.path}");
    final content = file.readAsStringSync();
    print("Content excerpts:");
    for (var line in content.split('\n')) {
      if (line.contains('vyoma_timetable')) {
        print(line);
      }
    }
  } else {
    print("No plist found.");
  }
}
