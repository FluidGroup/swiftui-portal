import SwiftUI
import UIKit

/// Displays the live rendering of an existing, mounted UIView.
/// The source keeps its state and layout; the destination uses its untransformed size.
public struct PortalView: View {

  public struct Configuration: Equatable, Sendable {

    public var matchesAlpha: Bool
    public var matchesTransform: Bool
    public var matchesPosition: Bool
    public var allowsHitTesting: Bool
    public var forwardsClientHitTestingToSourceView: Bool
    public var hidesSourceView: Bool

    public init(
      matchesAlpha: Bool = false,
      matchesTransform: Bool = false,
      matchesPosition: Bool = false,
      allowsHitTesting: Bool = true,
      forwardsClientHitTestingToSourceView: Bool = true,
      hidesSourceView: Bool = true
    ) {
      self.matchesAlpha = matchesAlpha
      self.matchesTransform = matchesTransform
      self.matchesPosition = matchesPosition
      self.allowsHitTesting = allowsHitTesting
      self.forwardsClientHitTestingToSourceView = forwardsClientHitTestingToSourceView
      self.hidesSourceView = hidesSourceView
    }

    /// Keeps the original visible and passes touches through the mirror.
    public static let mirror = Self(
      allowsHitTesting: false,
      forwardsClientHitTestingToSourceView: false,
      hidesSourceView: false
    )
  }

  private let source: UIView?
  private let sourceID: PortalSource.ID?
  private let configuration: Configuration

  public init(sourceView: UIView?, configuration: Configuration = .init()) {
    self.source = sourceView
    self.sourceID = nil
    self.configuration = configuration
  }

  /// Displays a source registered in another branch of the same on-screen view tree.
  /// An unmounted source leaves this portal empty with zero intrinsic size.
  public init(source: PortalSource.ID, configuration: Configuration = .init()) {
    self.source = nil
    self.sourceID = source
    self.configuration = configuration
  }

  public var body: some View {
    if let sourceID {
      let storage = sourceID.storage
      let size = storage.sourceView == nil ? CGSize.zero : storage.size ?? .zero
      Representable(portal: self, source: storage.sourceView, size: size)
        .frame(width: size.width, height: size.height)
    } else {
      Representable(portal: self, source: source, size: nil)
    }
  }

  func configure(_ portal: NativePortalView) {
    configure(portal, source: sourceID?.storage.sourceView ?? source)
  }

  private func configure(_ portal: NativePortalView, source: UIView?) {
    let sourceChanged = portal.sourceView !== source
    if sourceChanged {
      portal.disconnect()
    }
    portal.matchesAlpha = configuration.matchesAlpha
    portal.matchesTransform = configuration.matchesTransform
    portal.matchesPosition = configuration.matchesPosition
    portal.allowsHitTesting = configuration.allowsHitTesting
    portal.forwardsClientHitTestingToSourceView = configuration.forwardsClientHitTestingToSourceView
    if sourceChanged {
      portal.sourceView = source
    }
    // Native hiding must be applied after binding, including same-source updates.
    portal.hidesSourceView = configuration.hidesSourceView
    portal.invalidateIntrinsicContentSize()
  }

  struct Representable: UIViewRepresentable {

    let portal: PortalView
    let source: UIView?
    let size: CGSize?

    func makeUIView(context: Context) -> NativePortalView {
      guard let view = NativePortalView(sourceView: nil) else {
        preconditionFailure("Native portal is unavailable on this runtime")
      }
      portal.configure(view, source: source)
      return view
    }

    func updateUIView(_ uiView: NativePortalView, context: Context) {
      portal.configure(uiView, source: source)
    }

    func sizeThatFits(
      _ proposal: ProposedViewSize,
      uiView: NativePortalView,
      context: Context
    ) -> CGSize? {
      if let size {
        return size
      }
      let size = uiView.intrinsicContentSize
      return size.width > 0 && size.height > 0 ? size : nil
    }

    static func dismantleUIView(_ uiView: NativePortalView, coordinator: ()) {
      uiView.disconnect()
    }
  }
}
