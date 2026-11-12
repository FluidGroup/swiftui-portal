import SwiftUI

@main
struct PortalMirrorDemoApp: App {

  var body: some Scene {
    WindowGroup {
      TabView {
        MirrorBlurDemo()
          .tabItem { Label("Reflection", systemImage: "water.waves") }

        SeparateHierarchyDemo()
          .tabItem { Label("Separate", systemImage: "square.on.square") }
      }
    }
  }

}
