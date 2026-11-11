import SwiftUI
import UIKit

/// Mounts content once and supplies its original view and a live, noninteractive mirror.
/// Place `source` exactly once in the layout and keep it mounted while displaying the mirror.
public struct MirrorView<Content: View, Layout: View>: View {

  private let content: Content
  private let layout: (MirrorSource<Content>, PortalView) -> Layout

  @State private var sourceView: UIView?
  @State private var sourceSize: CGSize?

  public init(
    @ViewBuilder content: () -> Content,
    @ViewBuilder layout: @escaping (MirrorSource<Content>, PortalView) -> Layout
  ) {
    self.content = content()
    self.layout = layout
  }

  public var body: some View {
    layout(
      MirrorSource(
        content: content,
        onSizeChange: { sourceSize = $0 },
        onAppear: { sourceView = $0 },
        onDisappear: { view in
          if sourceView === view {
            sourceView = nil
          }
        }
      ),
      PortalView(sourceView: sourceView, configuration: .mirror, size: sourceSize)
    )
  }

}

public struct MirrorSource<Content: View>: View {

  private let content: Content
  private let onSizeChange: (CGSize) -> Void
  private let onAppear: (UIView?) -> Void
  private let onDisappear: (UIView?) -> Void

  @State private var reference = Reference()
  @State private var contentSize: CGSize?

  fileprivate init(
    content: Content,
    onSizeChange: @escaping (CGSize) -> Void,
    onAppear: @escaping (UIView?) -> Void,
    onDisappear: @escaping (UIView?) -> Void
  ) {
    self.content = content
    self.onSizeChange = onSizeChange
    self.onAppear = onAppear
    self.onDisappear = onDisappear
  }

  public var body: some View {
    Representable(
      content: content,
      reference: reference,
      onContentSizeChange: { contentSize = $0 }
    )
      .frame(idealWidth: contentSize?.width, idealHeight: contentSize?.height)
      .onGeometryChange(for: CGSize.self) { $0.size } action: { onSizeChange($0) }
      .onAppear { onAppear(reference.view) }
      .onDisappear { onDisappear(reference.view) }
  }

  private final class Reference {
    weak var view: UIView?
  }

  private struct Representable: UIViewControllerRepresentable {

    let content: Content
    let reference: Reference
    let onContentSizeChange: (CGSize) -> Void

    func makeUIViewController(context: Context) -> UIHostingController<AnyView> {
      let controller = UIHostingController(
        rootView: rootView(environment: context.environment)
      )
      controller.safeAreaRegions = []
      controller.view.backgroundColor = .clear
      reference.view = controller.view
      return controller
    }

    func updateUIViewController(_ uiViewController: UIHostingController<AnyView>, context: Context) {
      uiViewController.rootView = rootView(environment: context.environment)
    }

    private func rootView(environment: EnvironmentValues) -> AnyView {
      AnyView(
        // The hosting root is constrained to its UIKit bounds; measure its child.
        VStack(spacing: 0) {
          content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { onContentSizeChange($0) }
        }
        .environment(\.self, environment)
      )
    }

    func sizeThatFits(
      _ proposal: ProposedViewSize,
      uiViewController: UIHostingController<AnyView>,
      context: Context
    ) -> CGSize? {
      uiViewController.sizeThatFits(
        in: CGSize(
          width: proposal.width ?? .greatestFiniteMagnitude,
          height: proposal.height ?? .greatestFiniteMagnitude
        )
      )
    }

  }

}

#if DEBUG

private struct MirrorDemo: View {

  @State private var showsMirror = true

  var body: some View {
    VStack(spacing: 24) {
      MirrorView {
        MirrorCounter()
      } layout: { source, mirror in
        VStack(spacing: 24) {
          source
          if showsMirror {
            mirror
              .rotationEffect(.degrees(-6))
          }
        }
      }

      Toggle("Show mirror", isOn: $showsMirror)
    }
    .padding(32)
  }
}

private struct MirrorCounter: View {

  @State private var count = 0

  var body: some View {
    Button {
      withAnimation(.snappy) { count += 1 }
    } label: {
      Text("Count \(count)")
        .font(.largeTitle.bold())
        .contentTransition(.numericText())
        .padding(32)
        .frame(width: 260)
        .foregroundStyle(.white)
        .background(.indigo, in: RoundedRectangle(cornerRadius: 24))
    }
  }
}

#Preview("Live mirror") {
  MirrorDemo()
}

#endif
