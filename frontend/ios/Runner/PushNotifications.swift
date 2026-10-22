import Flutter
import UIKit
import UserNotifications

// The iOS side of the channel Dart shares with Android: permission, the APNs token,
// banners while the app is open, taps, and the notifications left on screen.
final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {
  static let shared = PushNotifications()

  private static let tokenKey = "apns_token"

  // APNs may never answer: offline, or on a simulator without network.
  private static let tokenTimeout: TimeInterval = 15

  private var channel: FlutterMethodChannel?
  private var token: String?
  private var waitingForToken: [FlutterResult] = []
  private var tokenRequest = 0

  // The notification tapped before Dart asked for it, which it does once listening.
  private var opened: Int?
  private var dartListening = false

  func attach(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "it.casamichela.app/notifications", binaryMessenger: messenger)

    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }

    self.channel = channel
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
    case "token":
      requestToken(result)
    // One token per install: the caller tells the server to forget it.
    case "deleteToken":
      result(true)
    case "takeOpened":
      dartListening = true
      result(opened)
      opened = nil
    case "tidy":
      tidy(call.arguments as? [String: Any] ?? [:], result)
    case "clear":
      removeShown(where: { _, _ in true }) { result(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // "granted", "prompt" while the system has not asked yet, "denied" once only the
  // Settings app can change it. Answered on the main thread, where Flutter expects it.
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

  private func requestToken(_ result: @escaping FlutterResult) {
    if let token {
      result(token)
      return
    }

    waitingForToken.append(result)

    guard waitingForToken.count == 1 else {
      return
    }

    tokenRequest += 1
    let request = tokenRequest

    UIApplication.shared.registerForRemoteNotifications()

    DispatchQueue.main.asyncAfter(deadline: .now() + Self.tokenTimeout) { [weak self] in
      guard let self, self.tokenRequest == request else {
        return
      }

      self.answerToken(FlutterError(code: "no_token", message: "APNs did not answer", details: nil))
    }
  }

  private func answerToken(_ answer: Any) {
    let waiting = waitingForToken
    waitingForToken = []
    tokenRequest += 1

    waiting.forEach { $0(answer) }
  }

  // From the app delegate, on the main thread.
  func registered(_ deviceToken: Data) {
    let value = deviceToken.map { String(format: "%02x", $0) }.joined()
    let before = UserDefaults.standard.string(forKey: Self.tokenKey)
    let asked = !waitingForToken.isEmpty

    UserDefaults.standard.set(value, forKey: Self.tokenKey)
    token = value
    answerToken(value)

    // A new token for an install that had one: Dart hands it to the server.
    if !asked && before != nil && before != value {
      tell("renewed", nil)
    }
  }

  func failed(_ error: Error) {
    answerToken(FlutterError(code: "no_token", message: error.localizedDescription, details: nil))
  }

  // Silent pushes only take a notification off the screen; alerts reach willPresent.
  func received(_ userInfo: [AnyHashable: Any], completion: @escaping (UIBackgroundFetchResult) -> Void) {
    guard userInfo["type"] as? String == "dismiss", let id = Self.id(of: userInfo) else {
      completion(.noData)
      return
    }

    removeShown(where: { shown, _ in shown == id }) { [weak self] in
      self?.tell("dismissed", id)
      completion(.newData)
    }
  }

  // Shown with the app open too, as on Android.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if let id = Self.id(of: notification.request.content.userInfo) {
      tell("arrived", id)
    }

    completionHandler([.banner, .list, .sound])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    defer { completionHandler() }

    guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
      let id = Self.id(of: response.notification.request.content.userInfo)
    else {
      return
    }

    if dartListening {
      tell("opened", id)
    } else {
      opened = id
    }
  }

  private func tidy(_ arguments: [String: Any], _ result: @escaping FlutterResult) {
    let unread = Set(arguments["unread"] as? [Int] ?? [])
    let listed = Set(arguments["listed"] as? [Int] ?? [])
    let millis = (arguments["listedAt"] as? NSNumber)?.doubleValue ?? 0
    let listedAt = Date(timeIntervalSince1970: millis / 1000)

    removeShown(where: { id, shownAt in
      !unread.contains(id) && (listed.contains(id) || shownAt < listedAt)
    }) {
      result(nil)
    }
  }

  // Matched by the id the server puts in every push, whatever identifier iOS gave it.
  private func removeShown(where gone: @escaping (Int, Date) -> Bool, then done: @escaping () -> Void) {
    let center = UNUserNotificationCenter.current()

    center.getDeliveredNotifications { shown in
      let identifiers = shown.compactMap { notification -> String? in
        guard let id = Self.id(of: notification.request.content.userInfo), gone(id, notification.date) else {
          return nil
        }

        return notification.request.identifier
      }

      center.removeDeliveredNotifications(withIdentifiers: identifiers)
      DispatchQueue.main.async(execute: done)
    }
  }

  private func tell(_ method: String, _ argument: Any?) {
    DispatchQueue.main.async {
      self.channel?.invokeMethod(method, arguments: argument)
    }
  }

  private static func id(of userInfo: [AnyHashable: Any]) -> Int? {
    if let number = userInfo["id"] as? Int {
      return number
    }

    if let text = userInfo["id"] as? String {
      return Int(text)
    }

    return nil
  }
}
