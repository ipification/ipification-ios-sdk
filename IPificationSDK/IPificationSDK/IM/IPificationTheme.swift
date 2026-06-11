//
//  IPificationTheme.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 6/1/2022.
//  Copyright © 2022 IPification Dev Team. All rights reserved.
//

import Foundation
import UIKit


/// Configures colors used by the SDK-provided instant-messaging interface.
public class IPificationTheme : NSObject {
    /// The navigation-bar title color.
    var toolbarTitleColor : UIColor = UIColor.black
    /// The navigation-bar cancel button color.
    var cancelBtnColor : UIColor = UIColor.systemBlue

    /// The main screen title color.
    var titleColor : UIColor = UIColor.black
    /// The screen description text color.
    var descColor : UIColor = UIColor.black
    /// The screen background color.
    var backgroundColor : UIColor = UIColor.white

    
    
    override init() {
        super.init()
    }
    /// Updates the primary screen colors while retaining toolbar defaults.
    public func updateScreen(titleColor: UIColor, descColor: UIColor, backgroundColor: UIColor){
        self.titleColor = titleColor
        self.descColor = descColor
        self.backgroundColor = backgroundColor
       
    }
    /// Updates all colors used by the instant-messaging screen.
    public func updateScreen(toolbarTitleColor: UIColor, cancelBtnColor: UIColor, titleColor: UIColor, descColor: UIColor, backgroundColor: UIColor){
        self.titleColor = titleColor
        self.descColor = descColor
        self.backgroundColor = backgroundColor
        self.toolbarTitleColor = toolbarTitleColor
        self.cancelBtnColor = cancelBtnColor
       
    }
    
    /// The process-wide instant-messaging theme.
    public static let sharedInstance = IPificationTheme()
}
