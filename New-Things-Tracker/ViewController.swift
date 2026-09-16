//
//  ViewController.swift
//  New-Things-Tracker
//
//  Created by Lucas Waunn on 9/16/26.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Background color
        view.backgroundColor = UIColor(named: "FogBackground")

        // Profile button (top left)
        let profileButton = UIBarButtonItem(
            image: UIImage(systemName: "person.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(profileTapped)
        )
        navigationItem.leftBarButtonItem = profileButton

        // Counter pill (top right) - we'll make this a custom view
        let counterLabel = UILabel()
        counterLabel.text = "0 firsts"
        counterLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        counterLabel.textColor = UIColor(named: "FogBackground")
        counterLabel.backgroundColor = UIColor(named: "DeepPineInk")
        counterLabel.textAlignment = .center
        counterLabel.layer.cornerRadius = 12
        counterLabel.clipsToBounds = true
        counterLabel.frame = CGRect(x: 0, y: 0, width: 80, height: 28)

        let counterItem = UIBarButtonItem(customView: counterLabel)
        navigationItem.rightBarButtonItem = counterItem
    }
    
    @objc func profileTapped() {
        print("Profile tapped")
    }


}

