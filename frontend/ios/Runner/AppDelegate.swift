import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    if let controller = window?.rootViewController as? FlutterViewController {
        let channel = FlutterMethodChannel(name: "com.halide/camera_metadata", binaryMessenger: controller.binaryMessenger)
        
        channel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "getMetadata" {
                self?.getCameraMetadata(result: result)
            } else {
                result(FlutterMethodNotImplemented)
            }
        }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func getCameraMetadata(result: @escaping FlutterResult) {
    let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .back)
    if let device = session.devices.first {
      result([
        "iso": Double(device.iso),
        "shutterSpeed": CMTimeGetSeconds(device.exposureDuration),
        "aperture": Double(device.lensAperture)
      ])
    } else {
      result(FlutterError(code: "UNAVAILABLE", message: "Camera or metadata unavailable", details: nil))
    }
  }
}
