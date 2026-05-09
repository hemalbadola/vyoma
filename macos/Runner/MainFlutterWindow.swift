import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // System-wide disable of spelling and autocorrect for Flutter views
    NSSpellChecker.shared.automaticallyIdentifiesLanguages = false
    
    RegisterGeneratedPlugins(registry: flutterViewController)
    if let appDelegate = NSApp.delegate as? AppDelegate {
      appDelegate.registerAuthDiagnosticsChannel(controller: flutterViewController)
    }
    
    super.awakeFromNib()
  }
}
