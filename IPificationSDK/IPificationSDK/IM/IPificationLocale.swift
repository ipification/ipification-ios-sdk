//
//  IPificationLocale.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 6/1/2022.
//  Copyright © 2022 IPification Dev Team. All rights reserved.
//

import Foundation


/// Configures localized text used by the SDK-provided instant-messaging interface.
public class IPificationLocale : NSObject {

    /// The title shown in the navigation bar.
    public var topTitle: String = "IPification"
    /// The main title shown on the IM selection screen.
    public var title: String = "Phone Number Verify"
    /// The instructions shown below the main title.
    public var desc: String = "Please tap on the preferred messaging app then follow our instruction on the screen"
    /// The title of the WhatsApp authentication button.
    public var whatsappBtnText: String = "Quick Login via Whatsapp"
    /// The title of the Viber authentication button.
    public var viberBtnText: String = "Quick Login via Viber"
    /// The title of the Telegram authentication button.
    public var telegramBtnText: String = "Quick Login via Telegram"
    /// The title of the cancel button.
    public var cancelBtnText: String = "Cancel"
    /// The message shown when the IM session cannot be found.
    public var errorMsgSessionNotFound = "The session has expired or could not be found. Please try again."
    /// The message shown when the IM session has already completed.
    public var errorMsgSessionAlreadyCompleted = "The session has already completed. Please back to the app."
    /// The confirmation button title used by IM error alerts.
    public var imErrorButtonText = "OK"
    /// The title used by IM error alerts.
    public var imErrorTitleText = "Error"
    /// The automatic-mode status text; `%@` is replaced with the provider name.
    public var autoDesc: String = "Booting up your %@ ..."
    
    
    override init() {
        super.init()
    }
    /// Replaces the user-visible text shown on the instant-messaging selection screen.
    public func updateScreen(titleBar topTitle: String, title: String, description: String, whatsappBtnText: String, viberBtnText: String, telegramBtnText: String, cancelBtnText: String){
        self.title = title
        self.topTitle = topTitle
        self.desc = description
        self.whatsappBtnText = whatsappBtnText
        self.viberBtnText = viberBtnText
        self.telegramBtnText = telegramBtnText
        self.cancelBtnText = cancelBtnText
    }
    
    /// The process-wide instant-messaging localization settings.
    public static let sharedInstance = IPificationLocale()
}
