import Portal
import SwiftUI

struct SeparateHierarchyDemo: View {

  @PortalSource private var counterPortal
  @State private var showsSource = true
  @State private var showsMirror = true
  @State private var revision = 0

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        Text("Separate Hierarchies")
          .font(.title2.bold())

        MainContent(source: counterPortal, showsSource: showsSource)

        VStack(spacing: 16) {
          Toggle("Show source", isOn: $showsSource)
            .accessibilityIdentifier("detached-source-enabled")
          Toggle("Show mirror", isOn: $showsMirror)
            .accessibilityIdentifier("detached-mirror-enabled")
          Button("Update parent · \(revision)") {
            revision += 1
          }
          .accessibilityIdentifier("detached-update-parent")
        }
        .frame(maxWidth: 300)
      }
      .frame(maxWidth: .infinity)
      .padding(24)
    }
    .background(Color(uiColor: .systemGroupedBackground))
    .safeAreaInset(edge: .bottom) {
      FloatingLayer(source: counterPortal, showsMirror: showsMirror)
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.regularMaterial)
    }
  }

  private struct MainContent: View {

    let source: PortalSource.ID
    let showsSource: Bool

    var body: some View {
      VStack(spacing: 8) {
        Text("Original · inside scroll content")
          .font(.caption)
          .foregroundStyle(.secondary)
        if showsSource {
          CounterCard()
            .portalSource(source)
        } else {
          Text("Source unmounted")
            .frame(width: 300, height: 156)
            .foregroundStyle(.secondary)
        }
      }
    }

  }

  private struct FloatingLayer: View {

    let source: PortalSource.ID
    let showsMirror: Bool

    var body: some View {
      VStack(spacing: 8) {
        Text("Live mirror · root inset")
          .font(.caption)
          .foregroundStyle(.secondary)
        ZStack {
          if showsMirror {
            PortalView(source: source, configuration: .mirror)
          }
        }
        .frame(width: 300, height: 156)
        .accessibilityIdentifier("detached-mirror")
      }
    }

  }

}

#Preview("Separate hierarchies") {
  SeparateHierarchyDemo()
}
