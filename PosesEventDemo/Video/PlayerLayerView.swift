import AVFoundation
import SwiftUI

/// Bare video without system controls. Several of these can show the same `AVPlayer`,
/// which is how the split mode keeps two panels in sync.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        // Same math as `.aspectRatio(contentMode: .fit)`, so `ImageFitGeometry` applies.
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.player = player
    }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }

    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
