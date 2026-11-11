import ProjectDescription

let project = Project(
  name: "PortalMirrorDemo",
  packages: [
    .local(path: ".."),
    .remote(
      url: "https://github.com/FluidGroup/swiftui-backdrop-blur",
      requirement: .upToNextMajor(from: "1.0.0")
    ),
  ],
  targets: [
    .target(
      name: "PortalMirrorDemo",
      destinations: [.iPhone, .iPad],
      product: .app,
      bundleId: "app.fluidgroup.PortalMirrorDemo",
      deploymentTargets: .iOS("17.0"),
      infoPlist: .extendingDefault(with: [
        "UILaunchScreen": .dictionary([:]),
      ]),
      sources: ["Sources/**"],
      dependencies: [
        .package(product: "Portal"),
        .package(product: "BackdropBlur"),
      ],
      settings: .settings(base: ["SWIFT_VERSION": "6.0"])
    ),
  ]
)
