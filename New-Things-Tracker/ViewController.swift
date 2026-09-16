//
//  ViewController.swift
//  New-Things-Tracker
//
//  Created by Lucas Waunn on 9/16/26.
//

import UIKit
import MapKit

// Esri tile URLs use level/row/column order rather than the standard z/x/y
private class EsriLightGrayTileOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        URL(string: "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/\(path.z)/\(path.y)/\(path.x)")!
    }
}

class ViewController: UIViewController {

    private enum Tab { case home, stats, map }
    private var currentTab: Tab = .home

    private var profileButtonView: UIButton!
    private var mapView: MKMapView!
    private var statsView: UIView!
    private var islandBar: UIView!
    private var tableView: UITableView!
    private var homeButton: UIButton!
    private var statsButton: UIButton!
    private var mapButton: UIButton!
    private var addButton: UIButton!

    private let sections: [(month: String, firsts: [First])] = [
        ("SEPTEMBER", [
            First(title: "Randolph Street Market", location: "West Loop", category: "Festival",
                  date: "Sat 6 Sep", duration: "4h 12m", photoCount: 23, extraPhotos: 21,
                  largePhotoColor: UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1),
                  smallPhotoColor: UIColor(red: 0.82, green: 0.70, blue: 0.63, alpha: 1)),
            First(title: "First Jazz Concert", location: "River North", category: "Music",
                  date: "Fri 19 Sep", duration: "2h 45m", photoCount: 11, extraPhotos: 9,
                  largePhotoColor: UIColor(named: "DustySage") ?? .systemGray,
                  smallPhotoColor: UIColor(named: "DustySage")?.withAlphaComponent(0.7) ?? .systemGray2),
        ]),
        ("AUGUST", [
            First(title: "Hot Air Balloon Ride", location: "Napa Valley", category: "Adventure",
                  date: "Sun 10 Aug", duration: "1h 30m", photoCount: 34, extraPhotos: 31,
                  largePhotoColor: UIColor(red: 0.79, green: 0.87, blue: 0.82, alpha: 1),
                  smallPhotoColor: UIColor(red: 0.70, green: 0.80, blue: 0.74, alpha: 1)),
            First(title: "Drive-In Movie Night", location: "Wicker Park", category: "Entertainment",
                  date: "Sat 23 Aug", duration: "3h 05m", photoCount: 8, extraPhotos: 6,
                  largePhotoColor: UIColor(named: "ClayAccent")?.withAlphaComponent(0.4) ?? .systemOrange,
                  smallPhotoColor: UIColor(named: "ClayAccent")?.withAlphaComponent(0.25) ?? .systemOrange),
        ]),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        navigationController?.navigationBar.isHidden = true

        setupMapView()
        setupStatsView()
        setupProfileButton()
        setupIslandBar()
        setupAddButton()
        setupCardsTable()
    }

    private func setupMapView() {
        mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.alpha = 0
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsScale = false

        // Esri World Light Gray — white bg, country/state borders, free without API key
        let tileOverlay = EsriLightGrayTileOverlay()
        tileOverlay.canReplaceMapContent = true
        mapView.addOverlay(tileOverlay, level: .aboveLabels)

        view.addSubview(mapView)

        let esriLabel = UILabel()
        esriLabel.translatesAutoresizingMaskIntoConstraints = false
        esriLabel.text = "Powered by Esri"
        esriLabel.font = UIFont.albertSans(.regular, size: 10)
        esriLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.4)
        view.addSubview(esriLabel)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            esriLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            esriLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -26),
        ])
    }

    private func setupStatsView() {
        let statsVC = StatsViewController()
        addChild(statsVC)
        statsView = statsVC.view
        statsView.translatesAutoresizingMaskIntoConstraints = false
        statsView.isHidden = true
        view.addSubview(statsView)
        statsVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            statsView.topAnchor.constraint(equalTo: view.topAnchor),
            statsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            statsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            statsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupProfileButton() {
        profileButtonView = UIButton(type: .system)
        profileButtonView.translatesAutoresizingMaskIntoConstraints = false
        profileButtonView.setImage(UIImage(systemName: "person.fill"), for: .normal)
        profileButtonView.tintColor = UIColor(named: "DeepPineInk")
        profileButtonView.backgroundColor = UIColor(named: "FogBackground")
        profileButtonView.layer.cornerRadius = 20
        profileButtonView.layer.shadowColor = UIColor.black.cgColor
        profileButtonView.layer.shadowOpacity = 0.15
        profileButtonView.layer.shadowOffset = CGSize(width: 0, height: 3)
        profileButtonView.layer.shadowRadius = 6
        profileButtonView.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        profileButtonView.addTarget(self, action: #selector(islandButtonPressDown(_:)), for: .touchDown)
        profileButtonView.addTarget(self, action: #selector(islandButtonPressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        view.addSubview(profileButtonView)

        NSLayoutConstraint.activate([
            profileButtonView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            profileButtonView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            profileButtonView.widthAnchor.constraint(equalToConstant: 40),
            profileButtonView.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func setupCardsTable() {
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 110, right: 0)
        tableView.register(FirstCardCell.self, forCellReuseIdentifier: FirstCardCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        view.insertSubview(tableView, belowSubview: islandBar)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: profileButtonView.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
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
            islandBar.widthAnchor.constraint(equalToConstant: 230),
        ])

        homeButton  = makeIslandButton(image: UIImage(named: "icon-house"),         action: #selector(homeTapped))
        statsButton = makeIslandButton(image: UIImage(systemName: "chart.bar.fill"), action: #selector(statsTapped))
        mapButton   = makeIslandButton(image: UIImage(named: "icon-map"),            action: #selector(mapTapped))

        islandBar.addSubview(homeButton)
        islandBar.addSubview(statsButton)
        islandBar.addSubview(mapButton)

        updateIslandSelection()

        NSLayoutConstraint.activate([
            homeButton.leadingAnchor.constraint(equalTo: islandBar.leadingAnchor, constant: 28),
            homeButton.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),

            statsButton.centerXAnchor.constraint(equalTo: islandBar.centerXAnchor),
            statsButton.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),

            mapButton.trailingAnchor.constraint(equalTo: islandBar.trailingAnchor, constant: -28),
            mapButton.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),
        ])
    }

    private func setupAddButton() {
        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false

        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        addButton.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        addButton.tintColor = UIColor(named: "FogBackground")
        addButton.backgroundColor = UIColor(named: "ClayAccent")
        addButton.layer.cornerRadius = 27
        addButton.layer.shadowColor = UIColor.black.cgColor
        addButton.layer.shadowOpacity = 0.2
        addButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        addButton.layer.shadowRadius = 8
        addButton.addTarget(self, action: #selector(addEventTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(islandButtonPressDown(_:)), for: .touchDown)
        addButton.addTarget(self, action: #selector(islandButtonPressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            addButton.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            addButton.widthAnchor.constraint(equalToConstant: 54),
            addButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func makeIslandButton(image: UIImage?, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(image, for: .normal)
        button.tintColor = UIColor(named: "FogBackground")
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(islandButtonPressDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(islandButtonPressUp(_:)),   for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }

    @objc private func islandButtonPressDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            sender.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        }
    }

    @objc private func islandButtonPressUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: .allowUserInteraction) {
            sender.transform = .identity
        }
    }

    @objc func profileTapped() {
        print("Profile tapped")
    }

    @objc func addEventTapped() {
        print("Add event tapped")
    }

    private func switchTo(_ tab: Tab) {
        guard tab != currentTab else { return }
        currentTab = tab

        mapView.alpha       = tab == .map   ? 1 : 0
        statsView.isHidden  = tab != .stats
        tableView.isHidden  = tab != .home
        profileButtonView.isHidden = tab != .home

        updateIslandSelection()
    }

    private func updateIslandSelection() {
        homeButton.setImage(UIImage(named: currentTab == .home
            ? "icon-house-filled" : "icon-house"), for: .normal)
        statsButton.setImage(UIImage(systemName: currentTab == .stats
            ? "chart.bar.fill" : "chart.bar"), for: .normal)
        mapButton.setImage(UIImage(named: currentTab == .map
            ? "icon-map-filled" : "icon-map"), for: .normal)

        homeButton.alpha  = currentTab == .home  ? 1.0 : 0.4
        statsButton.alpha = currentTab == .stats ? 1.0 : 0.4
        mapButton.alpha   = currentTab == .map   ? 1.0 : 0.4
    }

    @objc func homeTapped()  { switchTo(.home) }
    @objc func statsTapped() { switchTo(.stats) }
    @objc func mapTapped()   { switchTo(.map) }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].firsts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FirstCardCell.identifier, for: indexPath) as! FirstCardCell
        cell.configure(with: sections[indexPath.section].firsts[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.albertSans(.semiBold, size: 12),
            .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.7) ?? UIColor.white,
            .kern: 1.5,
        ]
        label.attributedText = NSAttributedString(string: sections[section].month, attributes: attrs)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        container.backgroundColor = .clear
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        36
    }
}
