import Flutter
import UIKit

// Saves a file where the user picks in the Files app, as Android's own save
// dialog does. Answers true once saved, false when the user cancels.
final class DocumentSaver: NSObject, UIDocumentPickerDelegate {
  private let channel: FlutterMethodChannel

  // The copy handed to the picker and the call waiting for its answer.
  private var pending: (folder: URL, result: FlutterResult)?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "it.casamichela.app/files", binaryMessenger: messenger)
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "saveFile" else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard
      let arguments = call.arguments as? [String: Any],
      let bytes = arguments["bytes"] as? FlutterStandardTypedData,
      let fileName = arguments["fileName"] as? String
    else {
      result(FlutterError(code: "bad_arguments", message: nil, details: nil))
      return
    }

    guard pending == nil else {
      result(FlutterError(code: "busy", message: nil, details: nil))
      return
    }

    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "no_window", message: nil, details: nil))
      return
    }

    // A folder of its own, so the file keeps its name and goes with it.
    let folder = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let file = folder.appendingPathComponent(fileName)

    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try bytes.data.write(to: file)
    } catch {
      try? FileManager.default.removeItem(at: folder)
      result(FlutterError(code: "write_failed", message: error.localizedDescription, details: nil))
      return
    }

    let picker: UIDocumentPickerViewController

    if #available(iOS 14.0, *) {
      picker = UIDocumentPickerViewController(forExporting: [file], asCopy: true)
    } else {
      picker = UIDocumentPickerViewController(url: file, in: .exportToService)
    }

    picker.delegate = self
    pending = (folder, result)
    presenter.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    finish(saved: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    finish(saved: false)
  }

  private func finish(saved: Bool) {
    guard let pending else { return }

    self.pending = nil
    try? FileManager.default.removeItem(at: pending.folder)
    pending.result(saved)
  }

  private static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
    var top = window?.rootViewController

    while let presented = top?.presentedViewController {
      top = presented
    }

    return top
  }
}
