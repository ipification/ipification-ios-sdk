//
//  IMButton.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 16/12/2021.
//  Copyright © 2021 IPification Dev Team. All rights reserved.
//
import UIKit
import Foundation
@IBDesignable class LeftAlignedButton: UIButton {
    override func layoutSubviews() {
        super.layoutSubviews()

        if let image = imageView?.image {

            let margin = 50 - image.size.width / 2
//            let titleRec = titleRect(forContentRect: bounds)
//            let titleOffset = (image.size.width) / 2
//            let titleOffset = (bounds.width - titleRec.width - image.size.width - margin) / 2

            contentHorizontalAlignment = UIControl.ContentHorizontalAlignment.left
            imageEdgeInsets = UIEdgeInsets(top: 10, left: margin, bottom: 10, right: 0)
            titleEdgeInsets = UIEdgeInsets(top: 0, left: margin/2, bottom: 0, right: 0)
            
        }
        imageView?.contentMode = .scaleAspectFit
        titleLabel?.font = titleLabel?.font.withSize(19)

        titleLabel?.textAlignment = .left
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 5
        let screen = UIScreen.main.bounds
        NSLayoutConstraint.activate([
//            centerXAnchor.constraint(equalTo: imStackView.centerXAnchor),
//            customAppleLoginBtn.centerYAnchor.constraint(equalTo: imStackView.centerYAnchor),
            widthAnchor.constraint(equalToConstant: screen.size.width - 40),
            heightAnchor.constraint(equalToConstant: 60)
            ])

    }
} 
