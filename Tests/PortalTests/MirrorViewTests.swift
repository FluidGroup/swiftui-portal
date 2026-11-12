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

    fixture.model.width = 80
    fixture.model.height = 90
    try await fixture.waitUntil {
      portal.bounds.size == CGSize(width: 80, height: 90)
        && portal.sourceView?.bounds.size == portal.bounds.size
    }
    #expect(fixture.probes.first === original)
  }
}

@MainActor
@Suite(.serialized)
struct PortalSourceTests {

  @Test
  func connectsSeparateBranchesAndKeepsIdentityAcrossParentUpdates() async throws {
    let fixture = MirrorFixture(detached: true)
    defer { fixture.close() }
    try await fixture.waitUntil { fixture.portal?.sourceView != nil && fixture.probes.count == 1 }
    let original = try #require(fixture.probes.first)
    let portal = try #require(fixture.portal)
    let source = try #require(portal.sourceView)
    let id = try #require(original.sourceID)

    fixture.model.revision += 1
    fixture.model.increment += 1
    fixture.model.width = 180
    fixture.model.height = 90
    fixture.model.localeIdentifier = "en_US"
    fixture.model.environmentValue = "updated"
    try await fixture.waitUntil {
      original.count == 1
        && original.localeIdentifier == "en_US"
        && original.environmentValue == "updated"
        && portal.bounds.size == CGSize(width: 180, height: 90)
    }
    #expect(original.sourceID == id)
    #expect(Set([id, try #require(original.sourceID)]).count == 1)
    #expect(portal.sourceView === source)
    #expect(fixture.probes.first === original)
    #expect(fixture.portals.last?.sourceView == nil)

    fixture.model.showsMirror = false
    try await fixture.waitUntil { portal.sourceView == nil && fixture.portals.count == 1 }
    #expect(original.count == 1)
    fixture.model.showsMirror = true
    try await fixture.waitUntil { fixture.portal?.sourceView === source }
    #expect(fixture.probes.first === original)
  }

  @Test
  func emptiesAndReconnectsWhenTheSourceUnmounts() async throws {
    let fixture = MirrorFixture(detached: true)
    defer { fixture.close() }
    try await fixture.waitUntil { fixture.portal?.sourceView != nil }
    let portal = try #require(fixture.portal)
    let sourceWasReleased = { [weak source = portal.sourceView] in source == nil }

    fixture.model.showsSource = false
    try await fixture.waitUntil {
      portal.sourceView == nil
        && portal.bounds.size == .zero
        && fixture.probes.isEmpty
        && sourceWasReleased()
    }

    fixture.model.showsSource = true
    try await fixture.waitUntil {
      portal.sourceView != nil
        && portal.bounds.size == CGSize(width: 120, height: 60)
        && fixture.probes.count == 1
    }
    #expect(fixture.portal === portal)
    #expect(fixture.probes.first?.count == 0)
  }

  @Test
  func rebindsTheSourceToAnotherIDWithoutRemountingContent() async throws {
    let fixture = MirrorFixture(detached: true)
    defer { fixture.close() }
    try await fixture.waitUntil { fixture.portal?.sourceView != nil && fixture.portals.count == 2 }
    let original = try #require(fixture.probes.first)
    let primary = try #require(fixture.portals.first)
    let secondary = try #require(fixture.portals.last)
    let source = try #require(primary.sourceView)
    let primaryID = try #require(original.sourceID)

    fixture.model.increment += 1
    try await fixture.waitUntil { original.count == 1 }
    fixture.model.routesToSecondary = true
    try await fixture.waitUntil {
      primary.sourceView == nil && primary.bounds.size == .zero
        && secondary.sourceView === source
        && secondary.bounds.size == CGSize(width: 120, height: 60)
    }
    #expect(fixture.probes.first === original)
    #expect(original.count == 1)
    #expect(original.sourceID != primaryID)

    fixture.model.routesToSecondary = false
    try await fixture.waitUntil { primary.sourceView === source && secondary.sourceView == nil }
    #expect(original.sourceID == primaryID)
    #expect(original.count == 1)
  }

}

@MainActor
@Observable
private final class MirrorModel {

  var increment = 0
  var showsMirror = true
  var showsSource = true
  var routesToSecondary = false
  var revision = 0
  var width: CGFloat = 120
  var height: CGFloat = 60
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
  var sourceID: PortalSource.ID?
  @State private var count = 0

  var body: some View {
    ProbeRepresentable(count: count, sourceID: sourceID)
      .frame(width: model.width, height: model.height)
      .onChange(of: model.increment) { count += 1 }
  }
}

private struct ProbeRepresentable: UIViewRepresentable {

  let count: Int
  var sourceID: PortalSource.ID?

  func makeUIView(context: Context) -> ContentProbe {
    ContentProbe(frame: .zero)
  }

  func updateUIView(_ uiView: ContentProbe, context: Context) {
    uiView.count = count
    uiView.localeIdentifier = context.environment.locale.identifier
    uiView.environmentValue = context.environment.mirrorTestValue
    uiView.sourceID = sourceID
  }
}

@MainActor
private final class ContentProbe: UIView {

  var count = 0
  var localeIdentifier = ""
  var environmentValue = ""
  var sourceID: PortalSource.ID?
}

private struct DetachedContent: View {

  let model: MirrorModel
  @PortalSource private var primary
  @PortalSource private var secondary

  var body: some View {
    VStack {
      Text("Revision \(model.revision)")
      DetachedSource(model: model, source: model.routesToSecondary ? secondary : primary)
      DetachedDestination(source: primary, isVisible: model.showsMirror)
      DetachedDestination(source: secondary, isVisible: true)
    }
    .environment(\.locale, Locale(identifier: model.localeIdentifier))
    .environment(\.mirrorTestValue, model.environmentValue)
  }

}

private struct DetachedSource: View {

  let model: MirrorModel
  let source: PortalSource.ID

  var body: some View {
    ZStack {
      if model.showsSource {
        StatefulContent(model: model, sourceID: source)
          .portalSource(source)
      }
    }
  }

}

private struct DetachedDestination: View {

  let source: PortalSource.ID
  let isVisible: Bool

  var body: some View {
    HStack {
      if isVisible {
        PortalView(source: source, configuration: .mirror)
      }
    }
  }

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
  var portals: [NativePortalView] { descendants(of: NativePortalView.self, in: window) }
  var portal: NativePortalView? { portals.first }

  init(detached: Bool = false) {
    let content = detached
      ? AnyView(DetachedContent(model: model))
      : AnyView(MirrorContent(model: model))
    hostingController = UIHostingController(
      rootView: AnyView(
        content
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
    #expect(
      predicate(),
      "Mirror update timed out: locale=\(probes.first?.localeIdentifier ?? "nil"), environment=\(probes.first?.environmentValue ?? "nil"), size=\(String(describing: portal?.bounds.size))"
    )
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
