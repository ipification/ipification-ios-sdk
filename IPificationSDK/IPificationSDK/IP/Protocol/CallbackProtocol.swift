//
//  CallbackProtocol.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 3/6/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation

protocol CallbackProtocol: AnyObject {
   
    func onSuccess(response: ResponseProtocol)
    func onError(error: IPificationException)
    func continueRequest(_ url : String)
    func handleIMResponse(_ imSession: IMSession)
    func onLogs(_ log : String)
    
}
