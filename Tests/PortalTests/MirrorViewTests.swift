import Observation
import SwiftUI
import Testing
import UIKit
@testable import Portal

@MainActor
@Suite(.serialized)
struct MirrorViewTests {

  @Test
  func mirrorsOneMountedSourceAndPreservesItsLocalState() async throws {
    let fixture = MirrorFixture()
    defer { fixture.close() }
    try await fixture.waitUntil { fixture.portal?.sourceView != nil && fixture.probes.count == 1 }
    let original = try #require(fixture.probes.first)
    let portal = try #require(fixture.portal)
    let source = try #require(portal.sourceView)

    #expect(original.isDescendant(of: source))
    #expect(source.window === fixture.window)
    #expect(!portal.hidesSourceView)
    #expect(!portal.allowsHitTesting)
    #expect(!portal.forwardsClientHitTestingToSourceView)

    fixture.model.increment += 1
    try await fixture.waitUntil { original.count == 1 }
    #expect(fixture.probes.count == 1)
    #expect(fixture.portal === portal)
    #expect(portal.sourceView === source)

    fixture.model.showsMirror = false
    try await fixture.waitUntil { fixture.portal == nil && portal.sourceView == nil }
    #expect(fixture.probes.first === original)
    #expect(original.count == 1)

    fixture.model.showsMirror = true
    try await fixture.waitUntil { fixture.portal?.sourceView === source }
    #expect(fixture.probes.first === original)
    #expect(original.count == 1)
  }

  @Test
  func inheritsEnvironmentAndTracksSourceSizeChanges() async throws {
    let fixture = MirrorFixture()
    defer { fixture.close() }
    try await fixture.waitUntil {
      fixture.probes.first?.localeIdentifier == "ja_JP"
        && fixture.probes.first?.environmentValue == "inherited"
        && fixture.portal?.bounds.size == CGSize(width: 120, height: 60)
    }
    let original = try #require(fixture.probes.first)
    let portal = try #require(fixture.portal)

    fixture.model.localeIdentifier = "en_US"
    fixture.model.environmentValue = "updated"
    fixture.model.width = 200
    try await fixture.waitUntil {
      original.localeIdentifier == "en_US"
        && original.environmentValue == "updated"
        && portal.bounds.size == CGSize(width: 200, height: 60)
    }
    #expect(fixture.probes.first === original)
    #expect(fixture.portal === portal)
  }
}

@MainActor
@Observable
private final class MirrorModel {

  var increment = 0
  var showsMirror = true
  var width: CGFloat = 120
  var localeIdentifier = "ja_JP"
  var environmentValue = "inherited"
}

private struct MirrorContent: View {

  let model: MirrorModel

  var body: some View {
    MirrorView {
      StatefulContent(model: model)
    } layout: { source, mirror in
      VStack(spacing: 24) {
        source
        if model.showsMirror {
          mirror
        }
      }
    }
    .environment(\.locale, Locale(identifier: model.localeIdentifier))
    .environment(\.mirrorTestValue, model.environmentValue)
  }
}

private struct StatefulContent: View {

  let model: MirrorModel
  @State private var count = 0

  var body: some View {
    ProbeRepresentable(count: count)
      .frame(width: model.width, height: 60)
      .onChange(of: model.increment) { count += 1 }
  }
}

private struct ProbeRepresentable: UIViewRepresentable {

  let count: Int

  func makeUIView(context: Context) -> ContentProbe {
    ContentProbe(frame: .zero)
  }

  func updateUIView(_ uiView: ContentProbe, context: Context) {
    uiView.count = count
    uiView.localeIdentifier = context.environment.locale.identifier
    uiView.environmentValue = context.environment.mirrorTestValue
  }
}

@MainActor
private final class ContentProbe: UIView {

  var count = 0
  var localeIdentifier = ""
  var environmentValue = ""
}

extension EnvironmentValues {
  @Entry fileprivate var mirrorTestValue = "default"
}

@MainActor
private final class MirrorFixture {

  let model = MirrorModel()
  let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
  private let hostingController: UIHostingController<AnyView>

  var probes: [ContentProbe] { descendants(of: ContentProbe.self, in: window) }
  var portal: NativePortalView? { descendants(of: NativePortalView.self, in: window).first }

  init() {
    hostingController = UIHostingController(
      rootView: AnyView(
        MirrorContent(model: model)
          .transaction {
            $0.animation = nil
            $0.disablesAnimations = true
          }
      )
    )
    window.rootViewController = hostingController
    window.isHidden = false
    window.layoutIfNeeded()
  }

  func waitUntil(_ predicate: @MainActor () -> Bool) async throws {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(3))
    while clock.now < deadline {
      window.setNeedsLayout()
      window.layoutIfNeeded()
      if predicate() { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(predicate(), "The expected mirror update did not arrive")
    throw MirrorUpdateTimeout()
  }

  func close() {
    window.isHidden = true
    hostingController.rootView = AnyView(EmptyView())
    window.rootViewController = nil
  }
}

private struct MirrorUpdateTimeout: Error {}

@MainActor
private func descendants<V: UIView>(of type: V.Type, in view: UIView) -> [V] {
  let matches = (view as? V).map { [$0] } ?? []
  return matches + view.subviews.flatMap { descendants(of: type, in: $0) }
}
