import 'dart:io';

class WindowSpy {

  Future<Map<String, dynamic>> spyOnUser() async {
    try {
      if (Platform.isMacOS) {
        return await _spyMacOS();
      } else {
        return {'spy_status': 'Disabled', 'active_app': 'Unavailable'};
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
        return {'active_window_error': 'Permission denied'};
      }
  }
}
