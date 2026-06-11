//
//  IPificationIMInstance.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 15/12/2021.
//  Copyright © 2021 IPification Dev Team. All rights reserved.
//

import Foundation
import UIKit

//public protocol IPificationIMDelegate{
//    func didSuccess(response: AuthorizationResponse)
//    func didFail(error: String)
//}
/// Creates and configures the SDK-provided instant-messaging authentication interface.
public class IPificationIMInstance{
    /// The instant-messaging session being presented.
    var imSession: IMSession?
    /// Called when IM authentication succeeds.
    var callbackSuccess: ((_ response: AuthorizationResponse) -> Void)?
    /// Called when IM authentication fails.
    var callbackFailed: ((_ response: IPificationException) -> Void)?
    /// Called when the user cancels IM authentication.
    var callbackCanceled: (() -> Void)?
    /// Called with IM authentication diagnostic messages.
    var callbackLog: ((_ response: String) -> Void)?
    /// The localized text used by the IM interface.
    var imLocale : IPificationLocale = IPificationLocale.sharedInstance
    /// The colors used by the IM interface.
    var imTheme : IPificationTheme = IPificationTheme.sharedInstance
    public init() {}

    /// Returns the appropriate login view controller for the current IM configuration.
    public func viewControllerForLogin() -> UIViewController{
        if(IPConfiguration.sharedInstance.IM_AUTO_MODE){
            return viewControllerForAutoLogin()
        }
        else if (imSession?.onlyAvailableAppList().count == 1){
            return viewControllerForAutoLogin()
        }
        else {
            return viewControllerForNormalLogin()
        }
    }
    
    /// Returns a view controller that lets the user select a messaging app.
    public func viewControllerForNormalLogin() -> UIViewController{
//        let viewModel: IMViewModel = .init()
        let storyboard = UIStoryboard.init(name: "IMStoryboard", bundle: Bundle(identifier: "bvl.IPificationSDK"))
        guard let homeVC = storyboard.instantiateViewController(withIdentifier: "IMStoryB") as? UINavigationController else {
            return UIViewController()
        }
        let imViewController = homeVC.visibleViewController as? IMViewController
        imViewController?.callbackCanceled = callbackCanceled
        imViewController?.callbackFailed = callbackFailed
        imViewController?.callbackSuccess = callbackSuccess
        imViewController?.callbackLog = callbackLog
        imViewController?.imSession = imSession
        imViewController?.imLocale = imLocale
        imViewController?.imTheme = imTheme
        return homeVC
    }
    
    /// Returns a view controller that automatically starts the preferred messaging app flow.
    public func viewControllerForAutoLogin() -> UIViewController{
//        let viewModel: IMViewModel = .init()
        let storyboard = UIStoryboard.init(name: "IMStoryboard", bundle: Bundle(identifier: "bvl.IPificationSDK"))
        guard let homeVC = storyboard.instantiateViewController(withIdentifier: "IMAutoStoryB") as? UINavigationController else {
            return UIViewController()
        }
        let imViewController = homeVC.visibleViewController as? IMAutoViewController
        imViewController?.callbackCanceled = callbackCanceled
        imViewController?.callbackFailed = callbackFailed
        imViewController?.callbackSuccess = callbackSuccess
        imViewController?.callbackLog = callbackLog
        imViewController?.imSession = imSession
        imViewController?.imLocale = imLocale
        imViewController?.imTheme = imTheme
        return homeVC
    }
    
    
}
