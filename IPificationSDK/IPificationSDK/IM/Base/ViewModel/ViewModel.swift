//
//  ViewModel.swift
//  IPificationSDK
//
//  Created by Mac on 22.11.2021.
//

import Foundation

protocol ViewModel: AnyObject {
//    var coordinator: BaseCoordinator? { get set }
    func tryRequest()
}

class BaseViewModel: ViewModel {
    func tryRequest() { }
    
//    public var coordinator: BaseCoordinator?
    
//    public var safeCoordinator: C {
//        // swiftlint:disable force_cast
//        return (coordinator as! C)
//        // swiftlint:enable force_cast
//    }
//
//    init(coordinator: C) {
//        self.coordinator = coordinator
//    }
//    /// Pop function
//    func pop( _ animated: Bool = true) {
//        coordinator?.pop(animated)
//    }
}
