//
//  ViewController.swift
//  New-Things-Tracker
//
//  Created by Lucas Waunn on 9/16/26.
//

import UIKit
import MapKit

class ViewController: UIViewController {

    private var profileButtonView: UIButton!
    private var mapView: MKMapView!
    private var islandBar: UIView!
    private var isMapVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "FogBackground")
        navigationController?.navigationBar.isHidden = true

        setupMapView()
        setupProfileButton()
        setupIslandBar()
    }

    private func setupMapView() {
        mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.alpha = 0
        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupProfileButton() {
        profileButtonView = UIButton(type: .system)
        profileButtonView.translatesAutoresizingMaskIntoConstraints = false
        profileButtonView.setImage(UIImage(systemName: "person.circle.fill"), for: .normal)
        profileButtonView.tintColor = UIColor(named: "DeepPineInk")
        profileButtonView.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        view.addSubview(profileButtonView)

        NSLayoutConstraint.activate([
            profileButtonView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            profileButtonView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            profileButtonView.widthAnchor.constraint(equalToConstant: 36),
            profileButtonView.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupIslandBar() {
        islandBar = UIView()
        islandBar.translatesAutoresizingMaskIntoConstraints = false
        islandBar.backgroundColor = UIColor(named: "DeepPineInk")
        islandBar.layer.cornerRadius = 30
        islandBar.layer.shadowColor = UIColor.black.cgColor
        islandBar.layer.shadowOpacity = 0.2
        islandBar.layer.shadowOffset = CGSize(width: 0, height: 4)
        islandBar.layer.shadowRadius = 12
        view.addSubview(islandBar)

        NSLayoutConstraint.activate([
            islandBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            islandBar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            islandBar.heightAnchor.constraint(equalToConstant: 60),
            islandBar.widthAnchor.constraint(equalToConstant: 160),
        ])

        let homeButton = makeIslandButton(icon: "house.fill", action: #selector(homeTapped))
        let mapButton  = makeIslandButton(icon: "map.fill",   action: #selector(mapTapped))

        islandBar.addSubview(homeButton)
        islandBar.addSubview(mapButton)

        NSLayoutConstraint.activate([
            homeButton.leadingAnchor.constraint(equalTo: islandBar.leadingAnchor, constant: 28),
            homeButton.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),

            mapButton.trailingAnchor.constraint(equalTo: islandBar.trailingAnchor, constant: -28),
            mapButton.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),
        ])
    }

    private func makeIslandButton(icon: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: icon), for: .normal)
        button.tintColor = UIColor(named: "FogBackground")
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    @objc func profileTapped() {
        print("Profile tapped")
    }

    @objc func homeTapped() {
        guard isMapVisible else { return }
        isMapVisible = false
        UIView.animate(withDuration: 0.35) {
            self.mapView.alpha = 0
        }
    }

    @objc func mapTapped() {
        guard !isMapVisible else { return }
        isMapVisible = true
        UIView.animate(withDuration: 0.35) {
            self.mapView.alpha = 1
        }
    }
}
