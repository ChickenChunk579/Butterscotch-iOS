import SwiftUI
import UIKit

@objc(TouchControlsViewController)
final class TouchControlsViewController: UIViewController {

    private let controlsModel: TouchControlsModel

    private var hostingController:
        UIHostingController<TouchControlsView>?

    private var touchInputView: TouchInputView?

    @objc(initWithKeyCallback:exitCallback:showControls:showFPS:)
    init(
        keyCallback: IOSTouchControlsKeyCallback?,
        exitCallback: IOSTouchControlsExitCallback?,
        showControls: Bool,
        showFPS: Bool
    ) {
        self.controlsModel = TouchControlsModel(
            keyCallback: keyCallback,
            exitCallback: exitCallback,
            showControls: showControls,
            showFPS: showFPS
        )

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {

        let container = UIView()

        container.backgroundColor = .clear
        container.isOpaque = false
        container.isUserInteractionEnabled = true

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.isOpaque = false
        view.isUserInteractionEnabled = true

        // --------------------------------------------------------------
        // SwiftUI visual layer
        // --------------------------------------------------------------

        let hosting = UIHostingController(
            rootView: TouchControlsView(
                model: controlsModel
            )
        )

        hosting.view.backgroundColor = .clear
        hosting.view.isOpaque = false

        // Raw UIKit view handles touches.
        hosting.view.isUserInteractionEnabled = false

        addChildViewController(hosting)

        hosting.view.frame = view.bounds

        hosting.view.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        view.addSubview(hosting.view)

        hosting.didMove(
            toParentViewController: self
        )

        hostingController = hosting

        // --------------------------------------------------------------
        // UIKit touch layer
        // --------------------------------------------------------------

        let input = TouchInputView(
            model: controlsModel
        )

        input.backgroundColor = .clear
        input.isOpaque = false
        input.isUserInteractionEnabled = true

        input.frame = view.bounds

        input.autoresizingMask = [
            .flexibleWidth,
            .flexibleHeight
        ]

        view.addSubview(input)

        touchInputView = input
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        hostingController?.view.frame = view.bounds
        touchInputView?.frame = view.bounds
    }

    @objc(setFPS:)
    func setFPS(_ fps: Double) {
        controlsModel.setFPS(fps)
    }
}