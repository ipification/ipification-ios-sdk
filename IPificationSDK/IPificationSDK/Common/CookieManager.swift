//
//  CookieManager.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 3/6/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation
class CookieManager : NSObject {
    /// The non-expired HTTP cookies retained by the SDK.
    private var cookies : [HTTPCookie] = []
    
    
    /// The process-wide cookie manager.
    static let sharedInstance = CookieManager()
    
    
    private override init() {
        super.init()
        
    }
    func initData(){
        cookies = []
    }
    
    func append(cookie : HTTPCookie){
        cookies.removeAll { existingCookie in
            existingCookie.name == cookie.name &&
            existingCookie.domain.caseInsensitiveCompare(cookie.domain) == .orderedSame &&
            existingCookie.path == cookie.path
        }

        if let expiresDate = cookie.expiresDate, expiresDate <= Date() {
            return
        }

        cookies.append(cookie)
    }
    func getCookies() -> [HTTPCookie]{
        cookies.removeAll { cookie in
            if let expiresDate = cookie.expiresDate {
                return expiresDate <= Date()
            }
            return false
        }
        return cookies
    }
}
