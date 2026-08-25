import UIKit
import SwiftUI

@objc(SwiftUIBridge)
public final class SwiftUIBridge: NSObject {

    @objc(makeLauncherViewController)
    public static func makeLauncherViewController() -> UIViewController {
        let view = LauncherView()

        return UIHostingController(
            rootView: view
        )
    }
}