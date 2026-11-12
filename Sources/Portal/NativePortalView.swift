// Adapted from FluidInterfaceKit's NativePortalView.swift.
// https://github.com/FluidGroup/FluidInterfaceKit/blob/main/Sources/FluidPortal/NativePortalView.swift
//
// MIT License
// Copyright (c) 2022 Muukii
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

/// Displays a live copy of a mounted view through UIKit's native portal.
///
/// The source retains its hierarchy, state, and animations. The native backend
/// can resolve portal hits against the original source subtree.
/// This renderer uses private API and fails initialization when absent.
@MainActor
public final class NativePortalView: UIView {

  private let backingView: UIView

  /// Creates a portal, or returns nil when the native runtime class is missing.
  public init?(sourceView: UIView?) {
    guard let portalClass = NSClassFromString(Runtime.className) as? UIView.Type else {
      return nil
    }
    backingView = portalClass.init(frame: .zero)
    super.init(frame: .zero)
    backingView.isUserInteractionEnabled = true
    addSubview(backingView)
    self.sourceView = sourceView
  }

  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  /// The original rendering. Reads reflect the native backend's actual binding.
  public var sourceView: UIView? {
    get { backingView.value(forKey: Runtime.sourceView) as? UIView }
    set {
      backingView.setValue(newValue, forKey: Runtime.sourceView)
      invalidateIntrinsicContentSize()
    }
  }

  /// Whether the source's drawing is hidden while this portal mirrors it.
  public var hidesSourceView: Bool {
    get { backingView.value(forKey: Runtime.hidesSourceView) as? Bool ?? false }
    set { backingView.setValue(newValue, forKey: Runtime.hidesSourceView) }
  }

  /// Whether the native portal participates in hit testing.
  public var allowsHitTesting: Bool {
    get { backingView.value(forKey: Runtime.allowsHitTesting) as? Bool ?? false }
    set { backingView.setValue(newValue, forKey: Runtime.allowsHitTesting) }
  }

  /// Whether UIKit resolves portal hits against the source's original subtree.
  public var forwardsClientHitTestingToSourceView: Bool {
    get { backingView.value(forKey: Runtime.forwardsClientHitTestingToSourceView) as? Bool ?? false }
    set { backingView.setValue(newValue, forKey: Runtime.forwardsClientHitTestingToSourceView) }
  }

  /// Whether the source's alpha is applied to the mirrored drawing.
  public var matchesAlpha: Bool {
    get { backingView.value(forKey: Runtime.matchesAlpha) as? Bool ?? false }
    set { backingView.setValue(newValue, forKey: Runtime.matchesAlpha) }
  }

  /// Whether the source's transform is applied to the mirrored drawing.
  public var matchesTransform: Bool {
    get { backingView.value(forKey: Runtime.matchesTransform) as? Bool ?? false }
    set { backingView.setValue(newValue, forKey: Runtime.matchesTransform) }
  }

  /// Whether the mirror follows the source's position instead of its own layout.
  public var matchesPosition: Bool {
    get { backingView.value(forKey: Runtime.matchesPosition) as? Bool ?? false }
    set { backingView.setValue(newValue, forKey: Runtime.matchesPosition) }
  }

  public override var intrinsicContentSize: CGSize {
    guard let sourceView else {
      return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }
    let size = sourceView.bounds.size
    return size.width > 0 && size.height > 0 ? size : sourceView.intrinsicContentSize
  }

  public override func layoutSubviews() {
    super.layoutSubviews()
    backingView.frame = bounds
  }

  /// Returns source hits while allowing inactive and empty regions to pass through.
  public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // Native forwarding can remain active even when allowsHitTesting is false.
    // Enforce that gate here, including the interval after source disconnection.
    guard allowsHitTesting, sourceView != nil else { return nil }
    let hitView = super.hitTest(point, with: event)
    // The wrapper has no interaction of its own. Preserve native hit handling
    // when client forwarding is disabled, as in the reference implementation.
    return hitView === self ? nil : hitView
  }

  /// Restores the source before removing the native reference.
  public func disconnect() {
    hidesSourceView = false
    sourceView = nil
  }

  private enum Runtime {

    static let className = decode("`VJQpsubmWjfx")
    static let sourceView = decode("tpvsdfWjfx")
    static let hidesSourceView = decode("ijeftTpvsdfWjfx")
    static let allowsHitTesting = decode("bmmpxtIjuUftujoh")
    static let forwardsClientHitTestingToSourceView = decode("gpsxbsetDmjfouIjuUftujohUpTpvsdfWjfx")
    static let matchesAlpha = decode("nbudiftBmqib")
    static let matchesTransform = decode("nbudiftUsbotgpsn")
    static let matchesPosition = decode("nbudiftQptjujpo")

    @inline(never)
    private static func decode(_ encoded: String) -> String {
      String(encoded.unicodeScalars.map { Character(UnicodeScalar($0.value - 1)!) })
    }
  }
}
