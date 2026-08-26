import SwiftUI

struct TouchControlsView: View {

    @ObservedObject var model: TouchControlsModel

    var body: some View {

        GeometryReader { geometry in

            ZStack {

                if model.showControls {

                    JoystickVisual(
                        x: model.joystickX,
                        y: model.joystickY
                    )
                    .position(
                        x: 92.0,
                        y:
                            geometry.size.height
                            - max(
                                geometry.safeAreaInsets.bottom,
                                20.0
                            )
                            - 92.0
                    )

                    ActionButtonsVisual(
                        zHeld: model.zHeld,
                        xHeld: model.xHeld,
                        cHeld: model.cHeld
                    )
                }

                ExitVisual()

                if model.showFPS {

                    FPSVisual(
                        fps: model.fps
                    )
                    .position(
                        x:
                            geometry.size.width
                            - max(
                                geometry.safeAreaInsets.trailing,
                                12.0
                            )
                            - 45.0,
                        y:
                            max(
                                geometry.safeAreaInsets.top,
                                12.0
                            ) + 16.0
                    )
                }
            }
            .frame(
                width: geometry.size.width,
                height: geometry.size.height
            )
        }
        .ignoresSafeArea()

        /*
         * TouchInputView handles all input.
         *
         * SwiftUI is purely visual.
         */
        .allowsHitTesting(false)
    }
}