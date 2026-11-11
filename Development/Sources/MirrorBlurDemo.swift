import BackdropBlur
import Portal
import SwiftUI

struct MirrorBlurDemo: View {

  @State private var blurRadius: CGFloat = 20
  @State private var blurEnabled = true
  @State private var direction = VariableBlurView.Direction.blurredBottomClearTop
  @State private var showsReflection = true
  @State private var fadesReflection = true

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        VStack(spacing: 6) {
          Text(showsReflection ? "Live Reflection" : "Mirror + Progressive Blur")
            .font(.title2.bold())
          Text("One counter, two live views")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }

        MirrorView {
          CounterCard()
        } layout: { source, mirror in
          VStack(spacing: showsReflection ? 6 : 20) {
            VStack(spacing: 8) {
              Text("Original · tap to count")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
              source
            }

            VStack(spacing: 8) {
              if !showsReflection {
                Text("Live mirror")
                  .font(.caption.weight(.medium))
                  .foregroundStyle(.secondary)
              }
              mirror
                .scaleEffect(x: 1, y: showsReflection ? -1 : 1)
                // Include the card's outline in the blur, with room for its halo.
                .padding(.horizontal, 40)
                .padding(.top, direction == .blurredTopClearBottom ? 40 : 0)
                .padding(.bottom, 40)
                .overlay {
                  VariableBlurView(
                    maxBlurRadius: blurEnabled ? blurRadius : 0,
                    configuration: .init(
                      direction: direction,
                      startOffset: showsReflection ? 0 : 0.6
                    )
                  )
                  // Blend the finite backdrop bounds into the surrounding view.
                  .mask { blurBoundsMask }
                }
                .mask {
                  LinearGradient(
                    colors: [
                      showsReflection && fadesReflection ? .black.opacity(0.65) : .black,
                      showsReflection && fadesReflection ? .clear : .black,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                  )
                }
                .animation(.snappy, value: blurEnabled)
            }
          }
        }

        VStack(spacing: 16) {
          Toggle("Reflection", isOn: $showsReflection)
            .accessibilityIdentifier("reflection-enabled")

          Toggle("Fade reflection", isOn: $fadesReflection)
            .accessibilityIdentifier("reflection-fade")
            .disabled(!showsReflection)

          Toggle("Progressive blur", isOn: $blurEnabled)
            .accessibilityIdentifier("blur-enabled")

          VStack(spacing: 4) {
            HStack {
              Text("Blur radius")
              Spacer()
              Text(blurRadius, format: .number.precision(.fractionLength(0)))
                .monospacedDigit()
            }
            Slider(value: $blurRadius, in: 0...40) {
              Text("Blur radius")
            }
            .accessibilityIdentifier("blur-radius")
          }

          Picker("Blur edge", selection: $direction) {
            Text("Blur bottom")
              .tag(VariableBlurView.Direction.blurredBottomClearTop)
            Text("Blur top")
              .tag(VariableBlurView.Direction.blurredTopClearBottom)
          }
          .pickerStyle(.segmented)
        }
        .font(.subheadline)
        .frame(maxWidth: 300)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .padding(.horizontal, 20)
    }
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private var blurBoundsMask: some View {
    HStack(spacing: 0) {
      LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
        .frame(width: 40)
      Rectangle()
      LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
        .frame(width: 40)
    }
    .mask {
      VStack(spacing: 0) {
        if direction == .blurredTopClearBottom {
          LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
            .frame(height: 40)
        }
        Rectangle()
        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
          .frame(height: 40)
      }
    }
  }

}

private struct CounterCard: View {

  @State private var count = 0

  var body: some View {
    Button {
      withAnimation(.snappy) {
        count += 1
      }
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("COUNTER")
            .font(.caption.weight(.semibold))
          Spacer()
          Image(systemName: "plus.circle.fill")
            .font(.title2)
        }

        Text(count, format: .number)
          .font(.system(size: 42, weight: .bold, design: .rounded))
          .contentTransition(.numericText())

        HStack(spacing: 4) {
          ForEach(0..<28) { index in
            Capsule()
              .fill(.white.opacity(index.isMultiple(of: 2) ? 1 : 0.35))
          }
        }
        .frame(height: 18)
      }
      .padding(20)
      .frame(width: 300, height: 156)
      .foregroundStyle(.white)
      .background(
        LinearGradient(
          colors: [.indigo, .blue, .teal],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        ),
        in: RoundedRectangle(cornerRadius: 24)
      )
    }
    .buttonStyle(.plain)
    .accessibilityLabel("Increment counter")
    .accessibilityValue("\(count)")
    .accessibilityIdentifier("source-counter")
  }

}

#if DEBUG

#Preview {
  MirrorBlurDemo()
}

#endif
