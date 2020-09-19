import Foundation
import Cocoa

extension NSPasteboard.Name {
    static let main = NSPasteboard.Name(Config.mainAppBundleIdentifier)
}

extension NSPasteboard.PasteboardType {
    static let plain = NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")
}

class SettingsPasteboard {
    static let shared = SettingsPasteboard()
    open var settings = [String: Any]()

    init() {
        importFile()
    }

    open func current() -> [String: Any] {
        let pasteboard = NSPasteboard(name: .main)
        if let element = pasteboard.pasteboardItems?.last, let str = element.string(forType: .plain), let data = str.data(using: .utf8) {
            do {
                let json = try JSONSerialization.jsonObject(with: data, options : .allowFragments) as! [String: Any]
                settings = json
            } catch {
                print("can't convert json")
            }
        }
        return settings
    }

    open func update() {
        let jsonStr = stringify(json: settings)
        let pasteboard = NSPasteboard(name: .main)
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(jsonStr, forType: .string)

        exportFile()
    }

    private func importFile() {
        if let jsonObject = try? JSONSerialization.jsonObject(with: Data(contentsOf: getPath()), options: []) as? [String: Any] {
            settings = jsonObject
        }
    }

    private func exportFile() {
        let path = getPath()
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.coordinate(writingItemAt: path, options: [], error: nil) { (URL) in
            if let jsonData = try? JSONSerialization.data(withJSONObject: self.settings, options: []) {
                try? JSONEncoder().encode(jsonData).write(to: path)
            }
        }
    }

    private func getPath() -> URL {
        let documentPath = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return documentPath.appendingPathComponent(Config.settingsFileName)
    }

    private func stringify(json: Any, prettyPrinted: Bool = false) -> String {
        var options: JSONSerialization.WritingOptions = []
        if prettyPrinted {
            options = JSONSerialization.WritingOptions.prettyPrinted
        }

        do {
            let data = try JSONSerialization.data(withJSONObject: json, options: options)
            if let string = String(data: data, encoding: .utf8) {
                return string
            }
        } catch {
            print(error)
        }

        return ""
    }
}
