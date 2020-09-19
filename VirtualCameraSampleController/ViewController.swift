import Cocoa

class ViewController: NSViewController {

    @IBOutlet weak var mainTextField: NSTextField!

    deinit {
        let panel = NSFontManager.shared.fontPanel(true)
        panel?.close()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        mainTextField.delegate = self
    }

    override func viewDidAppear() {
        mainTextField.window?.makeFirstResponder(mainTextField)
        let current = SettingsPasteboard.shared.current()
        mainTextField.stringValue = current["text1"] as? String ?? ""
    }

    @IBAction func sendButton_action(_ sender: Any) {
        SettingsPasteboard.shared.settings["text1"] = mainTextField.stringValue
        SettingsPasteboard.shared.update()
    }

    @IBAction func clearButton_action(_ sender: Any) {
        SettingsPasteboard.shared.settings["text1"] = ""
        SettingsPasteboard.shared.update()
    }
}

extension ViewController: NSTextFieldDelegate {

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if (commandSelector == #selector(NSResponder.insertNewline(_:))) {
            SettingsPasteboard.shared.settings["text1"] =  mainTextField.stringValue
            SettingsPasteboard.shared.update()
            return true
        }
        return false
    }
}
