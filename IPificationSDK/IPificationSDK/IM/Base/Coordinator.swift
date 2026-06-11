//
//  Coordinator.swift
//  IPificationSDK
//
//  Created by Mac on 22.11.2021.
//
import UIKit

/// Defines navigation lifecycle operations for SDK interface coordinators.
public protocol Coordinator: AnyObject {
    /// The navigation controller managed by the coordinator.
    var navigationController: UINavigationController? { get set }
    /// The coordinator that owns this child coordinator.
    var parentCoordinator: Coordinator? { get set }
    /// Launch view controller and other elements in here
    func start(coordinator: Coordinator)
    /// After navigate back or dismiss func delete coordinator from child coordinators
    func didFinish(coordinator: Coordinator)
    /// Clear all chlids
    func removeChildCoordinators()
    /// Overrride this func use for creating VC , ViewModels and other elements
    func start()
    /// Navigate back func if navigation exists
    func pop( _ animated: Bool)
    /// Segue with view controller and custom animation
    func segue(viewController: UIViewController, _ animated: Bool, transition: UIView.AnimationOptions?)
}

/// Provides reusable child-coordinator and navigation management.
public class BaseCoordinator: Coordinator {
    /**
     Segue function
     
     - parameter viewController: Which view controller will be shown after segue.
     - parameter animated: default value 'false'
     - parameter transition: Default value is flipfromLeft. If you want use this function , send animated param as true
     ```
     */
    public func segue(viewController: UIViewController, _ animated: Bool = false, transition: UIView.AnimationOptions? = nil) {
    }
    
    /// Current coordinator navigation item
    public var navigationController: UINavigationController?
    ///
    public var parentCoordinator: Coordinator?
    /// The child coordinators currently retained by this coordinator.
    var childCoordinators = [Coordinator]()
    
    /// Starts the coordinator. Subclasses override this method to present their flow.
    public func start() {
        fatalError("Start method should be implemented.")
    }
    /// Starting coordinator and adding coordinator as chlid
    public func start(coordinator: Coordinator) {
        childCoordinators += [coordinator]
        coordinator.parentCoordinator = self
        coordinator.start()
    }
    /// Remove coordinator ( segue , dismiss , navigate back )
    public func didFinish(coordinator: Coordinator) {
        guard let index = childCoordinators.firstIndex(where: {$0 === coordinator}) else { return }
        childCoordinators.remove(at: index)
    }
    /// Navigation back
    public func pop(_ animated: Bool) {
        removeChildCoordinators()
        parentCoordinator?.didFinish(coordinator: self)
        navigationController?.popViewController(animated: true)
    }
    /// Clear all child coordinators.
    public func removeChildCoordinators() {
        childCoordinators.forEach { $0.removeChildCoordinators() }
        childCoordinators.removeAll()
    }
}
