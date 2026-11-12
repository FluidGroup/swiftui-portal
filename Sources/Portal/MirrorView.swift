import SwiftUI
import UIKit

/// Mounts content once and supplies its original view and a live, noninteractive mirror.
/// Place `source` exactly once in the layout and keep it mounted while displaying the mirror.
public struct MirrorView<Content: View, Layout: View>: View {

  private let content: Content
  private let layout: (MirrorSource<Content>, PortalView) -> Layout

  @PortalSource private var source

  public init(
    @ViewBuilder content: () -> Content,
    @ViewBuilder layout: @escaping (MirrorSource<Content>, PortalView) -> Layout
  ) {
    self.content = content()
    self.layout = layout
  }

  public var body: some View {
    layout(
      MirrorSource(content: content, source: source),
      PortalView(source: source, configuration: .mirror)
    )
  }

}

public struct MirrorSource<Content: View>: View {

  private let content: Content
  private let source: PortalSource.ID

  @State private var reference = Reference()
  @State private var contentSize: CGSize?

  init(content: Content, source: PortalSource.ID) {
    self.content = content
    self.source = source
  }

  public var body: some View {
    Representable(
      content: content,
      reference: reference,
      onContentSizeChange: { contentSize = $0 }
    )
      .frame(idealWidth: contentSize?.width, idealHeight: contentSize?.height)
      .onGeometryChange(for: CGSize.self) { $0.size } action: {
        reference.size = $0
        reference.storage?.updateSize($0, for: reference.view)
      }
      .onAppear { reference.connect(to: source) }
      .onDisappear { reference.disconnect() }
      .onChange(of: source) { _, source in
        if reference.storage != nil {
          reference.connect(to: source)
        }
      }
  }

  private final class Reference {

    weak var view: UIView?
    var size: CGSize = .zero
    private(set) var storage: PortalSource.Storage?

    func connect(to source: PortalSource.ID) {
      if storage !== source.storage {
        disconnect()
      }
      storage = source.storage
      storage?.connect(view, size: size)
    }

    func disconnect() {
      storage?.disconnect(view)
      storage = nil
    }

  }

  private struct Representable: UIViewControllerRepresentable {

    let content: Content
    let reference: Reference
    let onContentSizeChange: (CGSize) -> Void

    func makeCoordinator() -> Reference {
      reference
    }

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

    static func dismantleUIViewController(
      _ uiViewController: UIHostingController<AnyView>,
      coordinator: Reference
    ) {
      coordinator.disconnect()
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
