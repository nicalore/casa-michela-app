import Flutter
import UIKit
import UserNotifications

// The system's answer about showing notifications: "granted", "prompt" while it
// has not asked yet, "denied" once only the Settings app can change it.
final class NotificationPermission: NSObject {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "it.casamichela.app/notifications", binaryMessenger: messenger)
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "status":
      status { result($0) }
    case "request":
      UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] _, _ in
        self?.status { result($0) }
      }
    case "openSettings":
      openSettings(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // Answered on the main thread, where Flutter expects every result.
  private func status(_ done: @escaping (String) -> Void) {
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let answer: String

      switch settings.authorizationStatus {
      case .notDetermined:
        answer = "prompt"
      case .denied:
        answer = "denied"
      default:
        answer = "granted"
      }

      DispatchQueue.main.async { done(answer) }
    }
  }

  // This app's notification page where iOS has one, its whole settings page before.
  private func openSettings(_ result: @escaping FlutterResult) {
    let address: String

    if #available(iOS 16.0, *) {
      address = UIApplication.openNotificationSettingsURLString
    } else {
      address = UIApplication.openSettingsURLString
    }

    guard let url = URL(string: address) else {
      result(false)
      return
    }

    UIApplication.shared.open(url) { opened in result(opened) }
  }
}
