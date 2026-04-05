import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  override func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    scheduleRegisterChannel(scene: scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    scheduleRegisterChannel(scene: scene)
  }

  private func scheduleRegisterChannel(scene: UIScene) {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }
    // Window / root VC may not exist until after `super` returns; try again next tick.
    DispatchQueue.main.async {
      appDelegate.ensureCameraMetadataChannelRegistered(preferredScene: scene)
    }
  }
}
