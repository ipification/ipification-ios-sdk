//
//  URLExt.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 3/6/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation

extension URL {
  func params() -> [String:Any] {
    var dict = [String:Any]()

    if let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
      if let queryItems = components.queryItems {
        for item in queryItems {
          // A query item with no "=" (e.g. "?foo") has a nil value; treat it as empty rather than crash.
          dict[item.name] = item.value ?? ""
        }
      }
      return dict
    } else {
      return [:]
    }
  }
}
