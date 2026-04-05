import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var textSystemObservers: [NSObjectProtocol] = []

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)

    applyGlobalTextInputDefaults()
    installTextSystemGuards()
  }

  deinit {
    for observer in textSystemObservers {
      NotificationCenter.default.removeObserver(observer)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func applyGlobalTextInputDefaults() {
    // Keep text services disabled at app level for any native text editor created by Flutter.
    UserDefaults.standard.register(defaults: [
      "NSSpellCheckerAutomaticallyIdentifiesLanguages": false,
      "NSAutomaticSpellingCorrectionEnabled": false,
      "NSAutomaticTextReplacementEnabled": false,
      "NSAutomaticDashSubstitutionEnabled": false,
      "NSAutomaticQuoteSubstitutionEnabled": false,
      "NSAutomaticCapitalizationEnabled": false,
    ])
    NSSpellChecker.shared.automaticallyIdentifiesLanguages = false
  }

  private func installTextSystemGuards() {
    let center = NotificationCenter.default
    let names: [Notification.Name] = [
      NSText.didBeginEditingNotification,
      NSText.didChangeNotification,
      NSWindow.didBecomeKeyNotification,
    ]

    textSystemObservers = names.map { name in
      center.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
        self?.disableTextServices(from: notification.object)
        self?.disableTextServices(from: NSApp.keyWindow?.firstResponder)
      }
    }
  }

  private func disableTextServices(from object: Any?) {
    if let textView = object as? NSTextView {
      disableTextServices(on: textView)
      return
    }

    if let window = object as? NSWindow {
      disableTextServices(from: window.firstResponder)
    }
  }

  private func disableTextServices(on textView: NSTextView) {
    textView.isContinuousSpellCheckingEnabled = false
    textView.isGrammarCheckingEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticTextCompletionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDataDetectionEnabled = false
    textView.isAutomaticLinkDetectionEnabled = false
  }
}
