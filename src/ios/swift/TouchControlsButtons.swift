import SwiftUI

struct ActionButtonsVisual: View {

    let zHeld: Bool
    let xHeld: Bool
    let cHeld: Bool

    var body: some View {

        GeometryReader { geometry in

            let bottom = max(
                geometry.safeAreaInsets.bottom,
                20
            )

            ZStack {

                ActionButtonVisual(
                    title: "Z",
                    held: zHeld
                )
                .position(
                    x: geometry.size.width - 82,
                    y: geometry.size.height - bottom - 78
                )

                ActionButtonVisual(
                    title: "X",
                    held: xHeld
                )
                .position(
                    x: geometry.size.width - 152,
                    y: geometry.size.height - bottom - 44
                )

                ActionButtonVisual(
                    title: "C",
                    held: cHeld
                )
                .position(
                    x: geometry.size.width - 82,
                    y: geometry.size.height - bottom - 148
                )
            }
        }
    }
}


struct ActionButtonVisual: View {

    let title: String
    let held: Bool

    var body: some View {

        ZStack {

            // MARK: - Soft glow
            Circle()
                .fill(.white.opacity(held ? 0.20 : 0.07))
                .frame(
                    width: held ? 82 : 68,
                    height: held ? 82 : 68
                )
                .blur(
                    radius: held ? 14 : 10
                )
                .opacity(held ? 1 : 0.65)

            // MARK: - Glass button
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    Circle()
                        .stroke(
                            .clear,
                            lineWidth: 1
                        )
                }
                .overlay {
                    // Small glass reflection
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    .clear,
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 18
                            )
                        )
                        .frame(
                            width: 28,
                            height: 28
                        )
                        .blur(radius: 2)
                        .offset(
                            x: -13,
                            y: -15
                        )
                }

            // MARK: - Letter
            Text(title)
                .font(
                    .system(
                        size: 22,
                        weight: .semibold,
                        design: .rounded
                    )
                )
                .foregroundStyle(.white)
                .shadow(
                    color: .black.opacity(0.25),
                    radius: 3,
                    y: 2
                )
                .scaleEffect(
                    held ? 0.94 : 1.0
                )
        }
        .frame(
            width: 68,
            height: 68
        )

        // Physical press
        .scaleEffect(
            held ? 0.88 : 1.0
        )

        // Depth shadow
        .shadow(
            color: .black.opacity(
                held ? 0.16 : 0.30
            ),
            radius: held ? 7 : 13,
            y: held ? 3 : 7
        )

        // IMPORTANT:
        // Do not use drawingGroup() here.
        // It can create rectangular-looking
        // compositing artifacts around blur/material.
        .animation(
            .spring(
                response: 0.18,
                dampingFraction: 0.68
            ),
            value: held
        )
    }
}
