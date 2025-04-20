import SwiftUI

struct BackgroundView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("BackgroundColor")
                    .ignoresSafeArea()

                // Top wavy pattern
                WavyShape(amplitude: 20, frequency: 0.1, phase: 0)
                    .fill(Color("BackgroundColor").opacity(0.5))
                    .frame(height: geometry.size.height * 0.5)
                    .offset(y: -geometry.size.height * 0.3)

                // Bottom wavy pattern
                WavyShape(amplitude: 15, frequency: 0.15, phase: .pi)
                    .fill(Color("BackgroundColor").opacity(0.7))
                    .frame(height: geometry.size.height * 0.4)
                    .offset(y: geometry.size.height * 0.35)
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

        // Draw the wave
        for x in stride(from: 0, to: rect.width, by: 1) {
            let relativeX = x / max(1, rect.width)  // Prevent division by zero
            let sinValue = sin(relativeX * frequency * .pi * 2 + phase)

            // Ensure y calculation doesn't result in NaN or infinity
            let y = sinValue.isFinite ? (sinValue * amplitude + rect.height / 2) : rect.height / 2

            path.addLine(to: CGPoint(x: x, y: y))
        }

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
