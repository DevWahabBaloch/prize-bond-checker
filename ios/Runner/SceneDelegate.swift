import Flutter
import IOSurface
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  static var privacyChannel: FlutterMethodChannel?
  private static var nextCoverGeneration = 0

  private var cover: UIView?
  private var coverLabel: UILabel?
  private var coverGeneration = 0
  private var requiresLock = false
  private var presentationCheck: CADisplayLink?
  private var expectedProof: UInt64?

  override func sceneWillResignActive(_ scene: UIScene) {
    cancelPresentationCheck()
    raisePrivacyCover()
    super.sceneWillResignActive(scene)
  }

  override func sceneDidEnterBackground(_ scene: UIScene) {
    cancelPresentationCheck()
    requiresLock = true
    raisePrivacyCover()
    super.sceneDidEnterBackground(scene)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    guard cover != nil else { return }
    coverLabel?.isHidden = false
    guard expectedProof == nil, let channel = Self.privacyChannel else { return }
    // The first two bits ensure an all-black or all-white drawable cannot pass.
    let proof = (UInt64.random(in: .min ... .max) & 0x3fff_ffff_ffff_ffff) | 0x8000_0000_0000_0000
    expectedProof = proof
    channel.invokeMethod("awaitSafeFrame", arguments: [
      "generation": coverGeneration,
      "requiresLock": requiresLock,
      "proof": String(format: "%016llx", proof),
    ])

    let link = CADisplayLink(target: self, selector: #selector(checkPresentation(_:)))
    presentationCheck = link
    link.preferredFramesPerSecond = 30
    link.add(to: .main, forMode: .common)
  }

  override func sceneDidDisconnect(_ scene: UIScene) {
    cancelPresentationCheck()
    super.sceneDidDisconnect(scene)
  }

  private func raisePrivacyCover() {
    guard let window else { return }
    Self.nextCoverGeneration += 1
    coverGeneration = Self.nextCoverGeneration
    if let cover, cover.superview === window {
      coverLabel?.isHidden = true
      window.bringSubviewToFront(cover)
      return
    }
    let shield = UIView(frame: window.bounds)
    shield.backgroundColor = UIColor(red: 250 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1)
    shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    shield.accessibilityViewIsModal = true
    let label = UILabel()
    label.text = "App locked. If this screen stays open, close and reopen the app."
    label.textColor = .darkGray
    label.textAlignment = .center
    label.numberOfLines = 0
    label.isHidden = true
    label.translatesAutoresizingMaskIntoConstraints = false
    shield.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerYAnchor.constraint(equalTo: shield.centerYAnchor),
      label.leadingAnchor.constraint(equalTo: shield.leadingAnchor, constant: 32),
      label.trailingAnchor.constraint(equalTo: shield.trailingAnchor, constant: -32),
    ])
    window.addSubview(shield)
    cover = shield
    coverLabel = label
  }

  @objc private func checkPresentation(_ link: CADisplayLink) {
    guard presentationCheck === link, let proof = expectedProof,
          window?.windowScene?.activationState == .foregroundActive,
          let flutterView = window?.rootViewController?.viewIfLoaded,
          let contents = flutterView.layer.presentation()?.contents,
          let latestContents = flutterView.layer.contents,
          CFGetTypeID(contents as CFTypeRef) == IOSurfaceGetTypeID(),
          CFGetTypeID(latestContents as CFTypeRef) == IOSurfaceGetTypeID() else { return }
    // The pinned FlutterMetalLayer publishes its drawable via CALayer.contents.
    // A display-link tick merely triggers inspection. There is no time-based release.
    let surface = contents as! IOSurfaceRef
    let latestSurface = latestContents as! IOSurfaceRef
    guard IOSurfaceGetID(surface) == IOSurfaceGetID(latestSurface),
          PrivacyFrameProof.matches(proof, on: surface) else { return }

    let generation = coverGeneration
    cancelPresentationCheck()
    cover?.removeFromSuperview()
    cover = nil
    coverLabel = nil
    requiresLock = false
    Self.privacyChannel?.invokeMethod("coverReleased", arguments: generation)
  }

  private func cancelPresentationCheck() {
    presentationCheck?.invalidate()
    presentationCheck = nil
    expectedProof = nil
  }
}
