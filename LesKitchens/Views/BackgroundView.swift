import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var phase1: CGFloat = 0
    @State private var phase2: CGFloat = .pi

    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base background color (brown/tan)
                Color(red: 0.58, green: 0.47, blue: 0.35)  // #947758
                    .edgesIgnoringSafeArea(.all)

                // Bottom wavy pattern (darker green)
                WavyShape(amplitude: 30, frequency: 0.08, phase: phase2)
                    .fill(Color(red: 0.4, green: 0.6, blue: 0.4))  // Darker green
                    .frame(height: geometry.size.height * 0.7)
                    .offset(y: geometry.size.height * 0.4)

                // Middle wavy pattern (medium green)
                WavyShape(amplitude: 25, frequency: 0.1, phase: phase1)
                    .fill(Color(red: 0.5, green: 0.7, blue: 0.5))  // Medium green
                    .frame(height: geometry.size.height * 0.6)
                    .offset(y: geometry.size.height * 0.45)

                // Top wavy pattern (lighter green)
                WavyShape(amplitude: 20, frequency: 0.12, phase: phase2)
                    .fill(Color(red: 0.6, green: 0.8, blue: 0.6))  // Lighter green
                    .frame(height: geometry.size.height * 0.5)
                    .offset(y: geometry.size.height * 0.5)
            }
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 0.05)) {
                    phase1 += 0.01
                    phase2 -= 0.01

                    // Reset phases to prevent potential floating-point precision issues
                    if phase1 > .pi * 2 {
                        phase1 = 0
                    }
                    if phase2 < -.pi * 2 {
                        phase2 = 0
                    }
                }
            }
        }
    }
}

struct WavyShape: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Safety check for zero width
        if rect.width <= 0 {
            return path
        }

        // Move to the bottom-leading corner
        path.move(to: CGPoint(x: 0, y: rect.height))

        // Draw the wave with smoother curve using more points
        let step: CGFloat = 2
        for x in stride(from: 0, to: rect.width, by: step) {
            let relativeX = x / max(1, rect.width)
            let sinValue = sin(relativeX * frequency * .pi * 2 + phase)

            // Ensure y calculation doesn't result in NaN or infinity
            let y = sinValue.isFinite ? (sinValue * amplitude + rect.height / 2) : rect.height / 2

            if x == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Add final point
        let finalX = rect.width
        let finalRelativeX = finalX / max(1, rect.width)
        let finalSinValue = sin(finalRelativeX * frequency * .pi * 2 + phase)
        let finalY =
            finalSinValue.isFinite ? (finalSinValue * amplitude + rect.height / 2) : rect.height / 2
        path.addLine(to: CGPoint(x: finalX, y: finalY))

        // Line to the bottom-trailing corner
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))

        // Close the path
        path.closeSubpath()

        return path
    }
}

#Preview {
    BackgroundView()
}
