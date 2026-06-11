//
//  ViewModelErrorAction.swift
//  IPificationSDK
//
//  Created by Mac on 22.11.2021.
//

import Foundation

enum UIError: Error {
    /// Network Error ( Connection failed , no internet connection , timeout)
    case NETWORK_ERROR
    /// Requst couldn't be started
    case REQUEST_ERROR
    /// Custom alert with message
    case ALERT(message: String)
}

protocol ViewModelErrorAction: AnyObject {
    /// Binding UIError
    func didErrorOccurred( _ state: UIError)
}
extension ViewModelErrorAction {
    /// Error handler , converting provider error to UIError.
//    func handleError( _ providerError: ProviderError) {
//        switch providerError {
//            case .SOMETHING_WENT_WRONG:
//                didErrorOccurred(.ALERT(message: "Something went wrong.Try again."))
//            case .URL_ERROR:
//                didErrorOccurred(.REQUEST_ERROR)
//            case .NO_INTERNET_CONNECTION:
//                didErrorOccurred(.NETWORK_ERROR)
//            case .CUSTOM(let message):
//                didErrorOccurred(.ALERT(message: message))
//        }
//    }
}
