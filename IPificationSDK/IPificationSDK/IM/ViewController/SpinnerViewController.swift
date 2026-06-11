//
//  SpinnerViewController.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 16/12/2021.
//  Copyright © 2021 IPification Dev Team. All rights reserved.
//

import Foundation
import UIKit

class SpinnerViewController: UIViewController {
    /// The activity indicator displayed while an IM operation is running.
    var spinner = UIActivityIndicatorView(style: .whiteLarge)

    override func loadView() {
        view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.3)
       
//        view.sizeToFit()
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        view.addSubview(spinner)

        spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
}
