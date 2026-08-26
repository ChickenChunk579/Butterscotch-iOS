import UIKit

final class TouchInputView: UIView {

    private weak var model: TouchControlsModel?

    private weak var joystickTouch: UITouch?

    private weak var zTouch: UITouch?
    private weak var xTouch: UITouch?
    private weak var cTouch: UITouch?

    private weak var exitTouch: UITouch?

    init(model: TouchControlsModel) {

        self.model = model

        super.init(frame: .zero)

        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true

        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Touches began

    override func touchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {

        guard let model else {
            return
        }

        guard model.showControls else {
            return
        }

        let size = bounds.size
        let safeArea = safeAreaInsets

        for touch in touches {

            let point =
                touch.location(
                    in: self
                )

            // Exit

            if exitTouch == nil &&
                model.exitRect(
                    in: size,
                    safeArea: safeArea
                ).contains(point) {

                exitTouch = touch
                continue
            }

            // Joystick

            if joystickTouch == nil {

                let center =
                    model.joystickCenter(
                        in: size,
                        safeArea: safeArea
                    )

                let distance =
                    hypot(
                        point.x - center.x,
                        point.y - center.y
                    )

                if distance <= 82.0 {

                    joystickTouch = touch

                    updateJoystick(touch)

                    continue
                }
            }

            // Z

            if zTouch == nil &&
                model.buttonRect(
                    key: ascii("Z"),
                    in: size,
                    safeArea: safeArea
                ).contains(point) {

                zTouch = touch

                model.setActionKey(
                    ascii("Z"),
                    held: true
                )

                continue
            }

            // X

            if xTouch == nil &&
                model.buttonRect(
                    key: ascii("X"),
                    in: size,
                    safeArea: safeArea
                ).contains(point) {

                xTouch = touch

                model.setActionKey(
                    ascii("X"),
                    held: true
                )

                continue
            }

            // C

            if cTouch == nil &&
                model.buttonRect(
                    key: ascii("C"),
                    in: size,
                    safeArea: safeArea
                ).contains(point) {

                cTouch = touch

                model.setActionKey(
                    ascii("C"),
                    held: true
                )

                continue
            }
        }
    }

    // MARK: - Touches moved

    override func touchesMoved(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        guard let joystickTouch else {
            return
        }

        if touches.contains(joystickTouch) {
            updateJoystick(joystickTouch)
        }
    }

    // MARK: - Touches ended

    override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {

        finishTouches(
            touches
        )
    }

    // MARK: - Touches cancelled

    override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {

        finishTouches(
            touches
        )
    }

    // MARK: - Cleanup

    private func finishTouches(
        _ touches: Set<UITouch>
    ) {

        guard let model else {
            return
        }

        for touch in touches {

            if touch === exitTouch {

                exitTouch = nil

                model.exit()

                continue
            }

            if touch === joystickTouch {

                joystickTouch = nil

                model.releaseJoystick()

                continue
            }

            if touch === zTouch {

                zTouch = nil

                model.setActionKey(
                    ascii("Z"),
                    held: false
                )

                continue
            }

            if touch === xTouch {

                xTouch = nil

                model.setActionKey(
                    ascii("X"),
                    held: false
                )

                continue
            }

            if touch === cTouch {

                cTouch = nil

                model.setActionKey(
                    ascii("C"),
                    held: false
                )

                continue
            }
        }
    }

    // MARK: - Joystick

    private func updateJoystick(
        _ touch: UITouch
    ) {

        guard let model else {
            return
        }

        let point =
            touch.location(
                in: self
            )

        let center =
            model.joystickCenter(
                in: bounds.size,
                safeArea: safeAreaInsets
            )

        model.updateJoystick(
            x: point.x - center.x,
            y: point.y - center.y
        )
    }

    // MARK: - Helpers

    private func ascii(
        _ character: Character
    ) -> Int32 {

        Int32(
            character.asciiValue ?? 0
        )
    }
}
