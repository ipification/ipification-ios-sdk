//
//  ResponseProtocol.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 3/6/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation
/// Defines common values exposed by authorization and coverage responses.
public protocol ResponseProtocol: AnyObject {
    func getPlainResponse() -> String
    func getError() -> String
    func getCode() -> String?
    func getState() -> String?
    func isAvailable() -> Bool
}
