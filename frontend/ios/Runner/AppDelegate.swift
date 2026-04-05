import Flutter
import UIKit
import AVFoundation
@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Must match the `CameraDescription.name` from the Flutter `camera` plugin — the **same**
  /// physical device that is running the preview session. Reading a different `AVCaptureDevice`
  /// via `DiscoverySession` alone returns stale/zero ISO and shutter, which yields EV 0 and bogus 8s readings.
  private var activeCaptureDeviceUniqueId: String?

  /// With `UIApplicationSceneManifest`, `window` is often nil in `didFinishLaunching` — the scene
  /// creates the window later. If we never register `com.halide/camera_metadata`, Dart gets
  /// `MissingPluginException` and metering stays at EV 0 / 8s.
  private var didRegisterCameraMetadataChannel = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    // Scene-based: window may still be nil; `ensure…` also runs from SceneDelegate.
    DispatchQueue.main.async { [weak self] in
      self?.ensureCameraMetadataChannelRegistered(preferredScene: nil)
    }
    return ok
  }

  /// Call from `SceneDelegate` once the scene’s window hosts `FlutterViewController`.
  func ensureCameraMetadataChannelRegistered(preferredScene: UIScene?) {
    guard !didRegisterCameraMetadataChannel else { return }
    guard let messenger = Self.binaryMessengerForFlutter(preferredScene: preferredScene) else {
      return
    }
    let channel = FlutterMethodChannel(name: "com.halide/camera_metadata", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "getMetadata":
        self?.getCameraMetadata(result: result)
      case "setupMeteringPoint":
        self?.setupCenterWeightedMetering(result: result)
      case "setActiveCaptureDevice":
        self?.setActiveCaptureDevice(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    didRegisterCameraMetadataChannel = true
    NSLog("HalideMeter: registered com.halide/camera_metadata channel")
  }

  private static func binaryMessengerForFlutter(preferredScene: UIScene?) -> FlutterBinaryMessenger? {
    if let ws = preferredScene as? UIWindowScene {
      if let vc = flutterViewController(in: ws) {
        return vc.binaryMessenger
      }
    }
    if let appDelegate = UIApplication.shared.delegate as? AppDelegate,
       let w = appDelegate.window,
       let vc = w.rootViewController as? FlutterViewController {
      return vc.binaryMessenger
    }
    for scene in UIApplication.shared.connectedScenes {
      guard let ws = scene as? UIWindowScene else { continue }
      if let vc = flutterViewController(in: ws) {
        return vc.binaryMessenger
      }
    }
    return nil
  }

  private static func flutterViewController(in windowScene: UIWindowScene) -> FlutterViewController? {
    let windows = windowScene.windows
    let ordered = windows.sorted { a, b in
      if a.isKeyWindow != b.isKeyWindow { return a.isKeyWindow && !b.isKeyWindow }
      return false
    }
    for window in ordered {
      if let f = window.rootViewController as? FlutterViewController {
        return f
      }
    }
    return nil
  }

  /// Flutter passes `CameraController.description.name` (on iOS this is the AVCaptureDevice uniqueID).
  private func setActiveCaptureDevice(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let uid = args["deviceId"] as? String, !uid.isEmpty else {
      result(FlutterError(code: "BAD_ARGS", message: "deviceId required", details: nil))
      return
    }
    activeCaptureDeviceUniqueId = uid
    NSLog("HalideMeter: bound active capture device id = %@", uid)
    result(true)
  }

  private func resolveCaptureDevice() -> AVCaptureDevice? {
    if let uid = activeCaptureDeviceUniqueId, let d = AVCaptureDevice(uniqueID: uid) {
      return d
    }
    let session = AVCaptureDevice.DiscoverySession(
      deviceTypes: [.builtInWideAngleCamera],
      mediaType: .video,
      position: .back
    )
    return session.devices.first
  }

  /// Returns current auto-exposure hardware values plus AE stability indicators.
  ///
  /// Per the Perplexity metering guide:
  /// - `isAdjusting`: true while camera AE is still converging; skip frames when true.
  /// - `targetOffset`: how far (EV) the current exposure deviates from the AE target.
  ///   Values near 0 indicate a stable, converged reading. Skip frames where |targetOffset| > 1.5.
  private func getCameraMetadata(result: @escaping FlutterResult) {
    guard let device = resolveCaptureDevice() else {
      result(FlutterError(code: "UNAVAILABLE", message: "Camera or metadata unavailable", details: nil))
      return
    }
    let iso = Double(device.iso)
    let shutter = CMTimeGetSeconds(device.exposureDuration)
    let aperture = Double(device.lensAperture)
    let adjusting = device.isAdjustingExposure
    let target = Double(device.exposureTargetOffset)
    NSLog(
      "HalideMeter: ISO=%.1f t=%.6f f=%.2f adjusting=%@ target=%.2f uid=%@",
      iso,
      shutter,
      aperture,
      adjusting ? "true" : "false",
      target,
      device.uniqueID
    )
    result([
      "iso": iso,
      "shutterSpeed": shutter,
      "aperture": aperture,
      "isAdjusting": adjusting,
      "targetOffset": target,
      "deviceUniqueId": device.uniqueID
    ])
  }

  /// Sets the camera's AE metering point to the frame center (center-weighted metering).
  /// Called once after the Flutter camera plugin initializes its session.
  private func setupCenterWeightedMetering(result: @escaping FlutterResult) {
    guard let device = resolveCaptureDevice() else {
      result(FlutterError(code: "UNAVAILABLE", message: "Camera not found", details: nil))
      return
    }
    do {
      try device.lockForConfiguration()
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = CGPoint(x: 0.5, y: 0.5)
      }
      if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }
      device.unlockForConfiguration()
      result(true)
    } catch {
      result(FlutterError(code: "CONFIG_ERROR", message: "Could not configure metering point: \(error)", details: nil))
    }
  }
}
