//
//  UIApplication+topController.swift
//  Loader
//
//  Created by samara on 18.03.2025.
//

import UIKit.UIApplication

extension UIApplication {
	/// The key window of the foreground scene, falling back to any window.
	public static var activeKeyWindow: UIWindow? {
		let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
		let foreground = scenes.filter { $0.activationState == .foregroundActive }
		let windows = (foreground.isEmpty ? scenes : foreground).flatMap(\.windows)
		return windows.first(where: \.isKeyWindow) ?? windows.first
	}

	/// This belongs to https://stackoverflow.com/a/30858591
	public class func topViewController(controller: UIViewController? = UIApplication.activeKeyWindow?.rootViewController) -> UIViewController? {
		if let navigationController = controller as? UINavigationController {
			return topViewController(controller: navigationController.visibleViewController)
		}
		if let tabController = controller as? UITabBarController {
			if let selected = tabController.selectedViewController {
				return topViewController(controller: selected)
			}
		}
		if let presented = controller?.presentedViewController, !presented.isBeingDismissed {
			return topViewController(controller: presented)
		}
		return controller
	}
}
