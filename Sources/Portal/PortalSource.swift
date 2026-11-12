import Observation
import SwiftUI
import UIKit

/// Owns a stable connection between a mounted source and portals in other view hierarchies.
@MainActor
@propertyWrapper
public struct PortalSource: DynamicProperty {

  /// An opaque source identity that can be passed to child views or through the environment.
  public struct ID: Hashable {

    let storage: Storage

    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.storage === rhs.storage
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(storage))
    }

  }

  @State private var storage = Storage()

  public init() {}

  public var wrappedValue: ID {
    ID(storage: storage)
  }

  @Observable
  final class Storage {

    private(set) weak var sourceView: UIView?
    private(set) var size: CGSize?

    func connect(_ view: UIView?, size: CGSize) {
      guard let view else { return }
      if sourceView !== view {
        sourceView = view
      }
      if self.size != size {
        self.size = size
      }
    }

    func updateSize(_ size: CGSize, for view: UIView?) {
      guard let view, sourceView === view else { return }
      if self.size != size {
        self.size = size
      }
    }

    func disconnect(_ view: UIView?) {
      guard let view, sourceView === view else { return }
      sourceView = nil
      size = nil
    }

  }

}

extension View {

  /// Registers this mounted content as the sole source for the connection.
  /// Apply once per ID and keep the source mounted while its portals are visible.
  public func portalSource(_ source: PortalSource.ID) -> some View {
    MirrorSource(content: self, source: source)
  }

}
