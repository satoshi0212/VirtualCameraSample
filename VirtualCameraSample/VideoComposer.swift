import Cocoa
import AVFoundation

@objc
protocol VideoComposerDelegate: class {
    func videoComposer(_ composer: VideoComposer, didComposeImageBuffer imageBuffer: CVImageBuffer)
}

@objcMembers
class VideoComposer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    weak var delegate: VideoComposerDelegate?

    //let inFlightSemaphore = DispatchSemaphore(value: 3)

    private let cameraCapture = CameraCapture()
    private let context = CIContext()
    private let session = URLSession(configuration: .default)
    private var settings: Settings = Settings.empty()
    private var settingsTimer: Timer?

    private let filter = CIFilter(name: "CISourceOverCompositing")
    private var textImage: CIImage?
    private lazy var noCameraBGImage: CIImage = {
        return NSImage(color: .black, size: NSSize(width: 1280, height: 720)).ciImage!
    }()

    private lazy var settingsURL = { () -> URL in
        let container = URL(fileURLWithPath: NSTemporaryDirectory())
        let settingsURL = container.appendingPathComponent("Settings.json")
        return settingsURL
    }()

    private let CVPixelBufferCreateOptions: [String: Any] = [
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
    ]

    deinit {
        stopRunning()
    }

    func startRunning() {
        startPollingSettings()
        cameraCapture.output.setSampleBufferDelegate(self, queue: .main)
        cameraCapture.startRunning()
    }

    func stopRunning() {
        settingsTimer?.invalidate()
        settingsTimer = nil
        cameraCapture.stopRunning()
    }

    let queue = DispatchQueue(label: "readQueue")

    private func startPollingSettings() {
        settingsTimer?.invalidate()
        settingsTimer = nil
        settingsTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            log("■ polling timer called.")

            let pasteboard = NSPasteboard(name: NSPasteboard.Name("tokyo.VirtualCameraSample"))

            var clipboardItems: [String] = []
            for element in pasteboard.pasteboardItems! {
                if let str = element.string(forType: NSPasteboard.PasteboardType(rawValue: "public.utf8-plain-text")) {
                    clipboardItems.append(str)
                }
            }
            log(clipboardItems)
            if let firstClipboardItem = clipboardItems.first {
                log(firstClipboardItem)

                if let data = Data(base64Encoded: firstClipboardItem),
                   let obj = try? JSONDecoder().decode(Settings.self, from: data),
                   obj != self.settings {

                    log(obj.text)
                    self.settings = obj
                    self.textImage = self.makeTextCIImage(text: obj.text,
                                                          fontName: obj.fontName,
                                                          fontSize: CGFloat(obj.textSize),
                                                          strokeColor: NSColor.init(hexString: obj.borderColor),
                                                          strokeWidth: CGFloat(obj.borderSize),
                                                          foregroundColor: NSColor.init(hexString: obj.textColor))
                }
            }

            log("■ polling timer called end.")
        }
        settingsTimer?.fire()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //log("■ CMIOMS: captureOutput called.")

        if output == cameraCapture.output {
            //_ = inFlightSemaphore.wait(timeout: .distantFuture)

            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            //inFlightSemaphore.signal()

            let cameraImage = settings.enableCamera ? CIImage(cvImageBuffer: imageBuffer) : noCameraBGImage
            let compositedImage = compose(bgImage: cameraImage, overlayImage: self.textImage)

            var pixelBuffer: CVPixelBuffer?

            _ = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(compositedImage.extent.size.width),
                Int(compositedImage.extent.height),
                kCVPixelFormatType_32BGRA,
                self.CVPixelBufferCreateOptions as CFDictionary,
                &pixelBuffer
            )

            if let pixelBuffer = pixelBuffer {
                context.render(compositedImage, to: pixelBuffer)
                delegate?.videoComposer(self, didComposeImageBuffer: pixelBuffer)
            }
        }
    }

    private func findPosition(bgSize: CGSize, overlayHeight: CGFloat, positionType: Int) -> NSPoint {
        var y: CGFloat = 0.0
        switch positionType {
        case 0:
            y = bgSize.height - overlayHeight - 40 // 上
        case 1:
            y = (bgSize.height - overlayHeight) / 2 // 中央
        case 2:
            y = 40 // 下
        default:
            y = 40
        }
        return NSPoint(x: 0, y: y)
    }

    private func makeTextCIImage(text: String, fontName: String, fontSize: CGFloat, strokeColor: NSColor, strokeWidth: CGFloat, foregroundColor: NSColor) -> CIImage? {
        let font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        let size = NSSize(width: 1280.0, height: 720)
        let position = findPosition(bgSize: size, overlayHeight: font.lineHeight(), positionType: settings.position)

//        log("■ font.lineHeight()")
//        log(font.lineHeight().description)
//        log(font.ascender.description)
//        log(font.descender.description)
//        log(font.leading.description)

        let image = NSImage(size: size, flipped: false) { (rect) -> Bool in
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let rectangle = NSRect(x: 0, y: position.y, width: size.width, height: font.lineHeight() + 12.0)
            let textAttributes = [
                //.backgroundColor: NSColor.green,
                .strokeColor: strokeColor,
                .foregroundColor: foregroundColor,
                .strokeWidth: -strokeWidth,
                .font: font,
                .paragraphStyle: paragraphStyle
                ] as [NSAttributedString.Key : Any]
            (text as NSString).draw(in: rectangle, withAttributes: textAttributes)
            return true
        }

        return image.ciImage
    }

    private func compose(bgImage: CIImage, overlayImage: CIImage?) -> CIImage {
        guard let filter = filter, let overlayImage = overlayImage else {
            return bgImage
        }
        filter.setValue(overlayImage, forKeyPath: kCIInputImageKey)
        filter.setValue(bgImage, forKeyPath: kCIInputBackgroundImageKey)
        return filter.outputImage!
    }

}

extension String {
    func targetIndex(index: Int) -> String.Index {
        return self.index(startIndex, offsetBy: index)
    }
}

extension NSColor {

    convenience init(hexString: String, alpha: CGFloat = 1.0) {
        let hexString: String = hexString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let scanner = Scanner(string: hexString)
        if (hexString.hasPrefix("#")) {
            scanner.currentIndex = scanner.string.targetIndex(index: 1)
        }
        var color: UInt64 = 0
        scanner.scanHexInt64(&color)
        let mask = 0x000000FF
        let r = Int(color >> 16) & mask
        let g = Int(color >> 8) & mask
        let b = Int(color) & mask
        let red   = CGFloat(r) / 255.0
        let green = CGFloat(g) / 255.0
        let blue  = CGFloat(b) / 255.0
        self.init(red:red, green:green, blue:blue, alpha:alpha)
    }

    func toHexString() -> String {
        var r:CGFloat = 0
        var g:CGFloat = 0
        var b:CGFloat = 0
        var a:CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let rgb:Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0
        return String(format:"#%06x", rgb)
    }
}

extension NSFont {

    func lineHeight() -> CGFloat {
        return CGFloat(ceilf(Float(ascender + abs(descender))))
        //return CGFloat(ceilf(Float(ascender + descender + leading)))
    }
}

struct Settings: Codable, Equatable {
    var text: String
    var position: Int
    var textSize: Int
    var borderSize: Int
    var textColor: String
    var borderColor: String
    var fontName: String
    var enableCamera: Bool
}

extension Settings {
    static func empty() -> Settings {
        return Settings(text: "",
                        position: 2,
                        textSize: 100,
                        borderSize: 2,
                        textColor: "#ffffff",
                        borderColor: "#000000",
                        fontName: "",
                        enableCamera: true)
    }
}

extension NSImage {

    convenience init(color: NSColor, size: NSSize) {
        self.init(size: size)
        lockFocus()
        color.drawSwatch(in: NSRect(origin: .zero, size: size))
        unlockFocus()
    }

    func resized(to newSize: NSSize) -> NSImage? {
        if let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(newSize.width), pixelsHigh: Int(newSize.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .calibratedRGB, bytesPerRow: 0, bitsPerPixel: 0
            ) {
            bitmapRep.size = newSize
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
            draw(in: NSRect(x: 0, y: 0, width: newSize.width, height: newSize.height), from: .zero, operation: .copy, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()

            let resizedImage = NSImage(size: newSize)
            resizedImage.addRepresentation(bitmapRep)
            return resizedImage
        }

        return nil
    }

    var ciImage: CIImage? {
        let newImage = self.resized(to: size)!
        guard let data = newImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: data) else { return nil }
        return CIImage(bitmapImageRep: bitmap)
    }
}
