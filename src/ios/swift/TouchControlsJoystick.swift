import SwiftUI

struct JoystickVisual: View {

    let x: CGFloat
    let y: CGFloat

    var body: some View {
        ZStack {

            // MARK: - Ambient glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.14),
                            .white.opacity(0.04),
                            .clear
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 100
                    )
                )
                .blur(radius: 18)
                .scaleEffect(1.15)

            // MARK: - Outer glass shell
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.16),
                                    .clear,
                                    .black.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.42),
                                    .white.opacity(0.08),
                                    .black.opacity(0.12)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(0.22),
                    radius: 20,
                    y: 10
                )

            // MARK: - Inner recessed glass
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.10),
                            .white.opacity(0.025),
                            .black.opacity(0.14)
                        ],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: 100
                    )
                )
                .padding(9)
                .overlay {
                    Circle()
                        .stroke(
                            .white.opacity(0.08),
                            lineWidth: 1
                        )
                        .padding(9)
                }

            // MARK: - Thumb ambient bloom
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .white.opacity(0.24),
                            .white.opacity(0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 48
                    )
                )
                .frame(width: 100, height: 100)
                .blur(radius: 14)
                .offset(x: x, y: y)

            // MARK: - Thumb
            Circle()
                .fill(.regularMaterial)
                .frame(width: 64, height: 64)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.92),
                                    .white.opacity(0.60),
                                    .white.opacity(0.38)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.70),
                                    .white.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(
                    color: .black.opacity(0.28),
                    radius: 12,
                    y: 7
                )
                .shadow(
                    color: .white.opacity(0.12),
                    radius: 5
                )
                .overlay(alignment: .topLeading) {

                    // Soft specular highlight
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .white.opacity(0.65),
                                    .white.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 14
                            )
                        )
                        .frame(width: 24, height: 24)
                        .blur(radius: 2)
                        .offset(x: 11, y: 9)
                }
                .offset(x: x, y: y)

            // Tiny center reflection
            Circle()
                .fill(.white.opacity(0.10))
                .frame(width: 4, height: 4)
                .blur(radius: 2)
                .offset(
                    x: x - 10,
                    y: y - 11
                )
        }
        .frame(width: 144, height: 144)
        .compositingGroup()
        .drawingGroup()
    }
}
