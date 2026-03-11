import 'dart:io';
import 'package:flutter/services.dart';

// Conditionally import win32/ffi only on Windows/Desktop to avoid compilation errors on web/mobile?
// Dart handles conditional imports automatically for 'dart:ffi' but 'package:win32' might be tricky.
// However, since we are using Platform check before calling, it *should* run if we just use dynamic invocation or careful structuring.
// For simplicity in this single file, we will stub out the Windows part with dynamic loading if possible, or just standard imports assuming the dep is present.
// The standard way in Flutter for FFI is just importing it. It won't crash on Android unless you CALL it.

// Imports for Windows FFI
import 'dart:ffi' as ffi;
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

// Imports for Android
import 'package:usage_stats/usage_stats.dart';

class WindowSpy {
  
  Future<Map<String, dynamic>> spyOnUser() async {
    try {
      if (Platform.isMacOS) {
        return await _spyMacOS();
      } else if (Platform.isWindows) {
        return await _spyWindows();
      } else if (Platform.isAndroid) {
        return await _spyAndroid();
      } else {
        return {'active_window': 'Unsupported Platform'};
      }
    } catch (e) {
      return {'active_window_error': e.toString()};
    }
  }

  // MAC OS
  Future<Map<String, dynamic>> _spyMacOS() async {
     const script = '''
      tell application "System Events"
        set frontApp to name of first application process whose frontmost is true
        
        set windowTitle to ""
        set browserUrl to ""
        
        try
          set windowTitle to name of first window of (first application process whose frontmost is true)
        on error
          set windowTitle to ""
        end try
        
        -- Browser Inspection Protocol
        if frontApp is "Google Chrome" or frontApp is "Google Chrome Beta" or frontApp is "Brave Browser" then
           try
             tell application frontApp to set browserUrl to URL of active tab of front window
           end try
        else if frontApp is "Safari" then
           try
             tell application "Safari" to set browserUrl to URL of front document
           end try
        end if
        
        return frontApp & ":::" & windowTitle & ":::" & browserUrl
      end tell
      ''';
      
      final result = await Process.run('osascript', ['-e', script]);
      
      if (result.exitCode == 0) {
        String raw = result.stdout.toString().trim();
        List<String> parts = raw.split(":::");
        String appName = parts[0];
        String windowTitle = parts.length > 1 ? parts[1] : "";
        String browserUrl = parts.length > 2 ? parts[2] : "";
        
        return {
          'active_app': appName,
          'window_title': windowTitle,
          'browser_url': browserUrl,
          'spy_status': 'Active'
        };
      } else {
        return {'active_window_error': 'Permission Denied'};
      }
  }

  // WINDOWS
  Future<Map<String, dynamic>> _spyWindows() async {
    // Requires 'win32' and 'ffi' packages.
    // 1. Get Foreground Window Handle
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return {'active_app': 'Unknown'};

    // 2. Get Window Text (Title)
    final length = GetWindowTextLength(hwnd);
    final buffer = wsalloc(length + 1);
    GetWindowText(hwnd, buffer, length + 1);
    final windowTitle = buffer.toDartString();
    free(buffer);

    // 3. Get Process ID -> Process Handle -> Module Name (App Name)
    final processId = calloc<DWORD>();
    GetWindowThreadProcessId(hwnd, processId);
    final hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId.value);
    
    String appName = "Windows App";
    if (hProcess != 0) {
      final moduleBuffer = wsalloc(MAX_PATH);
      // Logic to get module base name is complex via pure win32 API in Dart if using psapi. 
      // Simplified approach: Just use Window Title logic or skip deep process name for now if too complex.
      // But let's try getting the full executable path if possible.
      // Actually 'GetModuleFileNameEx' requires 'psapi.dart' which win32 package provides.
      
      final len = GetModuleFileNameEx(hProcess, 0, moduleBuffer, MAX_PATH);
      if (len > 0) {
        String fullPath = moduleBuffer.toDartString();
        appName = fullPath.split('\\').last; // e.g. "chrome.exe"
      }
      free(moduleBuffer);
      CloseHandle(hProcess);
    }
    free(processId);

    return {
      'active_app': appName,
      'window_title': windowTitle,
      'spy_status': 'Active'
    };
  }

  // ANDROID
  Future<Map<String, dynamic>> _spyAndroid() async {
    // Requires 'usage_stats' package.
    // Check permission first
    bool? isGranted = await UsageStats.checkUsagePermission();
    if (isGranted == null || !isGranted) {
      // Logic to ask user? Ideally UI handles this, but here we just report error.
      // Or we can try to grant it? Settings.ACTION_USAGE_ACCESS_SETTINGS
      return {'active_window_error': 'Usage Access Not Granted'};
    }

    try {
      DateTime endDate = DateTime.now();
      DateTime startDate = endDate.subtract(const Duration(seconds: 10)); // Very recent
      
      List<UsageInfo> queryEvents = await UsageStats.queryUsageStats(startDate, endDate);
      
      // Sort by last usage time
      queryEvents.sort((a, b) => (int.parse(b.lastTimeUsed ?? "0")).compareTo(int.parse(a.lastTimeUsed ?? "0")));
      
      if (queryEvents.isNotEmpty) {
        return {
           'active_app': queryEvents.first.packageName, // e.g. com.google.chrome
           'window_title': 'Android Activity', // Android prevents seeing window title
           'spy_status': 'Active'
        };
      }
      return {'active_app': 'Android Home'};
    } catch (e) {
      return {'active_window_error': e.toString()};
    }
  }
}
