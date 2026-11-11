# SwiftUI Portal

A live mirror of mounted UIKit or SwiftUI content. Extracted from
[ContextOverlay](https://github.com/FluidGroup/swiftui-context-overlay), with the
native implementation originally from FluidInterfaceKit. Uses private UIKit
runtime API on iOS 17 and later; availability and App Store acceptance are not guaranteed.

```swift
import Portal
import SwiftUI

MirrorView {
  CounterView()
} layout: { source, mirror in
  VStack(spacing: 24) {
    source
    mirror
      .rotationEffect(.degrees(-6))
  }
}
```

Place `source` once and keep it mounted. The mirror displays the same live
rendering, including state changes and animations, while leaving the original
visible. It passes touches through. It does not create another `CounterView`.

For an existing UIView, use the same renderer directly:

```swift
PortalView(sourceView: sourceView, configuration: .mirror)

// Hide the original drawing and enable native hit forwarding.
PortalView(sourceView: sourceView)

// UIKit access, including each native flag and explicit disconnection.
let portal = NativePortalView(sourceView: sourceView)
portal?.hidesSourceView = false
portal?.disconnect()
```

Destinations use the source's untransformed bounds size. Scaling a destination
does not resize the original content. Keep the source in the same on-screen
view tree, outside the destination's ancestor chain. Removing a SwiftUI
destination disconnects it and restores the original drawing.

Native forwarding is covered by UIKit hit-target tests; actual touch delivery
to relocated SwiftUI buttons and gestures is not guaranteed. `MirrorView`
deliberately uses display-only destinations.

The `Portal` library has no dependencies. Open `Package.swift` for the interactive
mirror preview. Native source attribution and the MIT license are retained.

The runnable progressive blur sample lives in `Development`. With Tuist installed,
run `tuist generate --path Development --no-open`, then open the generated workspace
and run `PortalMirrorDemo`. The mirror is flipped vertically and fades downward
like a reflection, with progressive blur increasing across its full height after
the flip. Turn off Fade reflection to inspect blur independently, or Reflection
to compare it with the upright mirror. The sample uses `BackdropBlur`
1.0.0 or later; the library itself remains dependency-free.
