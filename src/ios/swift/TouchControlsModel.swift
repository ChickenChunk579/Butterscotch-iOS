import SwiftUI
import UIKit

final class TouchControlsModel: ObservableObject {

    let keyCallback: IOSTouchControlsKeyCallback?
    let exitCallback: IOSTouchControlsExitCallback?

    let showControls: Bool
    let showFPS: Bool

    @Published var fps: Double = 0

    @Published var joystickX: CGFloat = 0
    @Published var joystickY: CGFloat = 0

    @Published var zHeld = false
    @Published var xHeld = false
    @Published var cHeld = false

    // ---------------------------------------------------------------------
    // Joystick state
    //
    // These represent the directions whose key-down event has already
    // been sent to the game.
    // ---------------------------------------------------------------------

    private var leftDown = false
    private var rightDown = false
    private var upDown = false
    private var downDown = false

    init(
        keyCallback: IOSTouchControlsKeyCallback?,
        exitCallback: IOSTouchControlsExitCallback?,
        showControls: Bool,
        showFPS: Bool
    ) {
        self.keyCallback = keyCallback
        self.exitCallback = exitCallback
        self.showControls = showControls
        self.showFPS = showFPS
    }

    // MARK: - FPS

    func setFPS(_ fps: Double) {

        DispatchQueue.main.async {
            self.fps = fps
        }
    }

    // MARK: - Exit

    func exit() {

        releaseJoystick()

        releaseActionKey(
            key: ascii("Z")
        )

        releaseActionKey(
            key: ascii("X")
        )

        releaseActionKey(
            key: ascii("C")
        )

        exitCallback?()
    }

    // MARK: - Keyboard callbacks

    func setKey(
        _ key: Int32,
        held: Bool
    ) {
        keyCallback?(key, held)
    }

    func setActionKey(
        _ key: Int32,
        held: Bool
    ) {

        switch key {

        case ascii("Z"):

            if zHeld == held {
                return
            }

            zHeld = held

        case ascii("X"):

            if xHeld == held {
                return
            }

            xHeld = held

        case ascii("C"):

            if cHeld == held {
                return
            }

            cHeld = held

        default:
            break
        }

        keyCallback?(key, held)
    }

    private func releaseActionKey(
        key: Int32
    ) {

        switch key {

        case ascii("Z"):

            if zHeld {
                zHeld = false
                keyCallback?(key, false)
            }

        case ascii("X"):

            if xHeld {
                xHeld = false
                keyCallback?(key, false)
            }

        case ascii("C"):

            if cHeld {
                cHeld = false
                keyCallback?(key, false)
            }

        default:
            break
        }
    }

    // MARK: - Joystick

    func updateJoystick(
        x: CGFloat,
        y: CGFloat
    ) {

        let deadZone: CGFloat = 18.0
        let maxDistance: CGFloat = 50.0

        var dx = x
        var dy = y

        let distance = hypot(dx, dy)

        if distance > maxDistance {

            let scale =
                maxDistance / distance

            dx *= scale
            dy *= scale
        }

        // --------------------------------------------------------------
        // Visual position.
        //
        // Do NOT use smoothing here. The joystick should track the
        // finger directly and return immediately to center.
        // --------------------------------------------------------------

        joystickX = dx
        joystickY = dy

        // --------------------------------------------------------------
        // Determine which directions are currently active.
        // --------------------------------------------------------------

        let newLeft =
            dx < -deadZone

        let newRight =
            dx > deadZone

        let newUp =
            dy < -deadZone

        let newDown =
            dy > deadZone

        // --------------------------------------------------------------
        // Only send a callback when a direction changes.
        //
        // This is the important part for menu navigation.
        // --------------------------------------------------------------

        updateJoystickKey(
            key: VK_LEFT,
            oldState: leftDown,
            newState: newLeft
        )

        leftDown = newLeft

        updateJoystickKey(
            key: VK_RIGHT,
            oldState: rightDown,
            newState: newRight
        )

        rightDown = newRight

        updateJoystickKey(
            key: VK_UP,
            oldState: upDown,
            newState: newUp
        )

        upDown = newUp

        updateJoystickKey(
            key: VK_DOWN,
            oldState: downDown,
            newState: newDown
        )

        downDown = newDown
    }

    private func updateJoystickKey(
        key: Int32,
        oldState: Bool,
        newState: Bool
    ) {

        // Nothing changed.
        if oldState == newState {
            return
        }

        keyCallback?(
            key,
            newState
        )
    }

    func releaseJoystick() {

        // --------------------------------------------------------------
        // Send key-up only for keys that are actually held.
        // --------------------------------------------------------------

        if leftDown {

            keyCallback?(
                VK_LEFT,
                false
            )

            leftDown = false
        }

        if rightDown {

            keyCallback?(
                VK_RIGHT,
                false
            )

            rightDown = false
        }

        if upDown {

            keyCallback?(
                VK_UP,
                false
            )

            upDown = false
        }

        if downDown {

            keyCallback?(
                VK_DOWN,
                false
            )

            downDown = false
        }

        // --------------------------------------------------------------
        // Immediately return the visual joystick to the center.
        // --------------------------------------------------------------

        joystickX = 0
        joystickY = 0
    }

    // MARK: - Geometry

    func joystickCenter(
        in size: CGSize,
        safeArea: UIEdgeInsets
    ) -> CGPoint {

        let bottom =
            max(
                safeArea.bottom,
                20.0
            )

        return CGPoint(
            x: 92.0,
            y:
                size.height
                - bottom
                - 92.0
        )
    }

    func buttonRect(
        key: Int32,
        in size: CGSize,
        safeArea: UIEdgeInsets
    ) -> CGRect {

        let bottom =
            max(
                safeArea.bottom,
                20.0
            )

        let center: CGPoint

        switch key {

        case ascii("Z"):

            center = CGPoint(
                x: size.width - 82.0,
                y: size.height - bottom - 78.0
            )

        case ascii("X"):

            center = CGPoint(
                x: size.width - 152.0,
                y: size.height - bottom - 44.0
            )

        default:

            center = CGPoint(
                x: size.width - 82.0,
                y: size.height - bottom - 148.0
            )
        }

        return CGRect(
            x: center.x - 34.0,
            y: center.y - 34.0,
            width: 68.0,
            height: 68.0
        )
    }

    func exitRect(
        in size: CGSize,
        safeArea: UIEdgeInsets
    ) -> CGRect {

        let top =
            max(
                safeArea.top,
                12.0
            )

        return CGRect(
            x: 16.0,
            y: top,
            width: 92.0,
            height: 38.0
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
