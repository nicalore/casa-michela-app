import Flutter
import UIKit

// UIKit stretches the Flutter view's last frame while a rotation animates and
// Flutter draws again only when it ends. For that time the view is hidden and
// a native copy of the app backdrop shows through, which stretches unseen; the
// view returns once Dart reports a frame drawn at the new size.
class RotationReportingViewController: FlutterViewController {
  private var channel: FlutterMethodChannel?
  private let backdrop = CAGradientLayer()
  private var revealTimer: Timer?

  private static let revealDuration: TimeInterval = 0.18

  // Should Dart never answer, the view comes back anyway.
  private static let revealTimeout: TimeInterval = 0.6

  override func viewDidLoad() {
    super.viewDidLoad()
    channel = FlutterMethodChannel(name: "it.casamichela.app/rotation", binaryMessenger: binaryMessenger)

    // Mirrors MobileBackground: AppTheme.trialDeepWater, trialTealDeep,
    // trialSeaGreen, trialLagoon at a 160° CSS angle. Glows are left out.
    backdrop.colors = [
      UIColor(red: 0x0B / 255.0, green: 0x33 / 255.0, blue: 0x50 / 255.0, alpha: 1).cgColor,
      UIColor(red: 0x0B / 255.0, green: 0x64 / 255.0, blue: 0x78 / 255.0, alpha: 1).cgColor,
      UIColor(red: 0x12 / 255.0, green: 0x90 / 255.0, blue: 0x7F / 255.0, alpha: 1).cgColor,
      UIColor(red: 0x1A / 255.0, green: 0xA2 / 255.0, blue: 0x7E / 255.0, alpha: 1).cgColor,
    ]
    backdrop.locations = [0, 0.45, 0.75, 1]
    backdrop.startPoint = CGPoint(x: 0.318, y: 0)
    backdrop.endPoint = CGPoint(x: 0.682, y: 1)
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)

    if backdrop.superlayer == nil, let host = view.superview {
      backdrop.frame = host.bounds
      host.layer.insertSublayer(backdrop, below: view.layer)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    backdrop.frame = view.superview?.bounds ?? view.bounds
  }

  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    super.viewWillTransition(to: size, with: coordinator)

    guard size != view.bounds.size, backdrop.superlayer != nil else { return }

    revealTimer?.invalidate()
    setViewOpacity(0, animated: false)

    coordinator.animate(alongsideTransition: nil) { [weak self] _ in
      guard let self else { return }

      self.revealTimer = Timer.scheduledTimer(withTimeInterval: Self.revealTimeout, repeats: false) { [weak self] _ in
        self?.reveal()
      }

      // Dart answers once a frame at the new size has been drawn.
      self.channel?.invokeMethod("didRotate", arguments: nil) { [weak self] _ in
        self?.reveal()
      }
    }
  }

  private func reveal() {
    revealTimer?.invalidate()
    revealTimer = nil

    if view.layer.opacity < 1 {
      setViewOpacity(1, animated: true)
    }
  }

  private func setViewOpacity(_ opacity: Float, animated: Bool) {
    CATransaction.begin()
    CATransaction.setDisableActions(!animated)
    CATransaction.setAnimationDuration(animated ? Self.revealDuration : 0)
    view.layer.opacity = opacity
    CATransaction.commit()
  }
}
