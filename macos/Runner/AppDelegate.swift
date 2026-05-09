import Cocoa
import FlutterMacOS
import Security

@main
class AppDelegate: FlutterAppDelegate {
  private var textSystemObservers: [NSObjectProtocol] = []
  private var authDiagnosticsChannel: FlutterMethodChannel?

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Firebase is initialized from Dart (`Firebase.initializeApp` in main.dart).
    // Avoid double `FirebaseApp.configure()` — can confuse Auth / Google Sign-In state.
    super.applicationDidFinishLaunching(notification)

    applyGlobalTextInputDefaults()
    installTextSystemGuards()
    installAuthDiagnosticsChannelWhenReady()
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

  private func installAuthDiagnosticsChannelWhenReady(retryCount: Int = 0) {
    if authDiagnosticsChannel != nil {
      return
    }

    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      registerAuthDiagnosticsChannel(controller: controller)
      return
    }

    if retryCount >= 20 {
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      self?.installAuthDiagnosticsChannelWhenReady(retryCount: retryCount + 1)
    }
  }

  func registerAuthDiagnosticsChannel(controller: FlutterViewController) {
    if authDiagnosticsChannel != nil {
      return
    }

    let channel = FlutterMethodChannel(
      name: "vyoma/macos_auth_diag",
      binaryMessenger: controller.engine.binaryMessenger
    )
    authDiagnosticsChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "internal", message: "AppDelegate deallocated", details: nil))
        return
      }

      switch call.method {
      case "googleSignInDebugSnapshot":
        result(self.googleSignInDebugSnapshot())
      case "clearGoogleSignInKeychainState":
        result(self.clearGoogleSignInKeychainState())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func googleSignInDebugSnapshot() -> [String: Any] {
    let keychainProbe = runKeychainProbe()
    return [
      "bundleIdentifier": Bundle.main.bundleIdentifier ?? "",
      "gidClientId": Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String ?? "",
      "gidServerClientId": Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String ?? "",
      "keychainAccessGroupsEntitlement": entitlementValue(key: "keychain-access-groups"),
      "appSandboxEntitlement": entitlementValue(key: "com.apple.security.app-sandbox"),
      "keychainProbe": keychainProbe,
    ]
  }

  private func entitlementValue(key: String) -> Any {
    guard let task = SecTaskCreateFromSelf(nil) else {
      return "SecTaskCreateFromSelf_failed"
    }
    guard let raw = SecTaskCopyValueForEntitlement(task, key as CFString, nil) else {
      return NSNull()
    }
    return bridgeEntitlementValue(raw)
  }

  private func bridgeEntitlementValue(_ value: CFTypeRef) -> Any {
    let anyObject = value as AnyObject
    if let arrayValue = anyObject as? [Any] {
      return arrayValue
    }
    if let stringValue = anyObject as? String {
      return stringValue
    }
    if let boolValue = anyObject as? Bool {
      return boolValue
    }
    if let numberValue = anyObject as? NSNumber {
      return numberValue
    }
    return String(describing: anyObject)
  }

  private func runKeychainProbe() -> [String: Any] {
    let service = "com.vyoma.app.gid.debug"
    let account = "google_sign_in_probe"
    let payload = "vyoma-probe-\(UUID().uuidString)".data(using: .utf8) ?? Data()

    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    SecItemDelete(deleteQuery as CFDictionary)

    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecValueData as String: payload,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)

    let readQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var readResult: CFTypeRef?
    let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &readResult)

    let fetchedData = readResult as? Data
    let payloadRoundTripMatch = fetchedData == payload

    let cleanupStatus = SecItemDelete(deleteQuery as CFDictionary)

    return [
      "addStatus": Int(addStatus),
      "addMessage": secStatusMessage(addStatus),
      "readStatus": Int(readStatus),
      "readMessage": secStatusMessage(readStatus),
      "cleanupStatus": Int(cleanupStatus),
      "cleanupMessage": secStatusMessage(cleanupStatus),
      "payloadRoundTripMatch": payloadRoundTripMatch,
    ]
  }

  private func secStatusMessage(_ status: OSStatus) -> String {
    if let raw = SecCopyErrorMessageString(status, nil) {
      return raw as String
    }
    return "Unknown OSStatus \(status)"
  }

  private func clearGoogleSignInKeychainState() -> [String: Any] {
    let group = keychainGoogleAccessGroup()

    let genericQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccessGroup as String: group,
    ]
    let internetQuery: [String: Any] = [
      kSecClass as String: kSecClassInternetPassword,
      kSecAttrAccessGroup as String: group,
    ]

    let genericStatus = SecItemDelete(genericQuery as CFDictionary)
    let internetStatus = SecItemDelete(internetQuery as CFDictionary)

    return [
      "accessGroup": group,
      "genericPasswordDeleteStatus": Int(genericStatus),
      "genericPasswordDeleteMessage": secStatusMessage(genericStatus),
      "internetPasswordDeleteStatus": Int(internetStatus),
      "internetPasswordDeleteMessage": secStatusMessage(internetStatus),
    ]
  }

  private func keychainGoogleAccessGroup() -> String {
    let fallback = "com.google.GIDSignIn"
    let groupsRaw = entitlementValue(key: "keychain-access-groups")
    guard let groups = groupsRaw as? [Any] else {
      return fallback
    }

    for group in groups {
      if let value = group as? String, value.hasSuffix(".com.google.GIDSignIn") {
        return value
      }
    }
    return fallback
  }
}
