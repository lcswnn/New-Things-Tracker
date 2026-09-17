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

// Reference layer adds roads, boundaries, and labels on top of the base
private class EsriLightGrayReferenceOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        URL(string: "https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/\(path.z)/\(path.y)/\(path.x)")!
    }
}

class ViewController: UIViewController {

    private enum Tab { case home, discover, stats, map }
    private var currentTab: Tab = .home

    // Island bar sits 60pt tall + 16pt gap above safeAreaLayoutGuide.bottomAnchor
    private let islandClearance: CGFloat = 60 + 16 + 10

    private var profileButtonView: UIButton!
    private var mapView: MKMapView!
    private var statsView: UIView!
    private var discoverView: UIView!
    private var discoverVC: DiscoverViewController!
    private var statsVC: StatsViewController!
    private var leftIsland: UIView!
    private var rightIsland: UIView!
    private var tableView: UITableView!
    private var homeButton: UIButton!
    private var discoverButton: UIButton!
    private var statsButton: UIButton!
    private var mapButton: UIButton!
    private var addButton: UIButton!
    private var addButtonContainer: UIView!

    private var navBarViews: [UIView] { [leftIsland, addButtonContainer, rightIsland] }
    private var greetingLabel: UILabel!
    private var dateLabel: UILabel!
    private var esriLabel: UILabel!
    private weak var headerFadeView: UIView?
    private let headerFadeLayer = CAGradientLayer()
    private var isBarHidden = false
    private var isMapMoving = false

    override var prefersStatusBarHidden: Bool { true }

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
        setupDiscoverView()
        setupProfileButton()
        setupHeaderLabels()
        setupCardsTable()
        setupHeaderFade()
        setupNavBar()           // last — stays above all content

        // Start off-screen for entrance animation
        let offscreen = CGAffineTransform(translationX: 0, y: 120)
        navBarViews.forEach { $0.transform = offscreen; $0.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let delays: [Double] = [0.06, 0.12, 0.06]
        for (view, delay) in zip(navBarViews, delays) {
            UIView.animate(withDuration: 0.52, delay: delay, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.6, options: [.curveEaseOut, .allowUserInteraction]) {
                view.transform = .identity
                view.alpha = 1
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let fadeView = headerFadeView {
            headerFadeLayer.frame = fadeView.bounds
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // tableView extends to the physical bottom, so include the safe area in its inset
        tableView.contentInset.bottom = islandClearance + view.safeAreaInsets.bottom
        // Child VCs get extra safe area so their scroll views auto-inset correctly
        guard discoverVC != nil, statsVC != nil else { return }
        let extra = UIEdgeInsets(top: 0, left: 0, bottom: islandClearance, right: 0)
        discoverVC.additionalSafeAreaInsets = extra
        statsVC.additionalSafeAreaInsets = extra
    }

    private func setupMapView() {
        mapView = MKMapView()
        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.alpha = 0
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsScale = false

        // Esri World Light Gray — base layer (terrain, water, land)
        let tileOverlay = EsriLightGrayTileOverlay()
        tileOverlay.canReplaceMapContent = true
        mapView.addOverlay(tileOverlay, level: .aboveLabels)

        // Reference layer adds roads, borders, and place outlines on top
        let referenceOverlay = EsriLightGrayReferenceOverlay()
        referenceOverlay.canReplaceMapContent = false
        mapView.addOverlay(referenceOverlay, level: .aboveLabels)

        let mapTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(mapTapGesture)

        view.addSubview(mapView)

        esriLabel = UILabel()
        esriLabel.translatesAutoresizingMaskIntoConstraints = false
        esriLabel.text = "Powered by Esri"
        esriLabel.font = UIFont.karla(.regular, size: 10)
        esriLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.4)
        esriLabel.isHidden = true
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

    private func setupDiscoverView() {
        discoverVC = DiscoverViewController()
        addChild(discoverVC)
        discoverView = discoverVC.view
        discoverView.translatesAutoresizingMaskIntoConstraints = false
        discoverView.isHidden = true
        view.addSubview(discoverView)
        discoverVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            discoverView.topAnchor.constraint(equalTo: view.topAnchor),
            discoverView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            discoverView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            discoverView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupStatsView() {
        statsVC = StatsViewController()
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
        profileButtonView.setImage(UIImage(named: "icon-account"), for: .normal)
        profileButtonView.imageEdgeInsets = UIEdgeInsets(top: 11, left: 11, bottom: 11, right: 11)
        profileButtonView.tintColor = UIColor(named: "FogBackground")
        profileButtonView.backgroundColor = UIColor(named: "DeepPineInk")
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

    private func setupHeaderLabels() {
        greetingLabel = UILabel()
        greetingLabel.translatesAutoresizingMaskIntoConstraints = false
        greetingLabel.text = currentGreeting()
        greetingLabel.font = UIFont.fraunces(.bold, size: 26)
        greetingLabel.textColor = UIColor(named: "FogBackground")
        view.addSubview(greetingLabel)

        dateLabel = UILabel()
        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.text = formattedToday()
        dateLabel.font = UIFont.karla(.regular, size: 14)
        dateLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.65)
        view.addSubview(dateLabel)

        NSLayoutConstraint.activate([
            greetingLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            greetingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            greetingLabel.trailingAnchor.constraint(equalTo: profileButtonView.leadingAnchor, constant: -12),

            dateLabel.topAnchor.constraint(equalTo: greetingLabel.bottomAnchor, constant: 3),
            dateLabel.leadingAnchor.constraint(equalTo: greetingLabel.leadingAnchor),
        ])
    }

    private func currentGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        default:      return "Good evening."
        }
    }

    private func formattedToday() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    private func setupCardsTable() {
        tableView = UITableView(frame: .zero, style: .grouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: islandClearance, right: 0)
        tableView.register(FirstCardCell.self, forCellReuseIdentifier: FirstCardCell.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupHeaderFade() {
        let fadeView = UIView()
        fadeView.translatesAutoresizingMaskIntoConstraints = false
        fadeView.isUserInteractionEnabled = false
        headerFadeView = fadeView
        view.insertSubview(fadeView, aboveSubview: tableView)

        let bg = UIColor(named: "DustySage") ?? UIColor(red: 0.70, green: 0.75, blue: 0.68, alpha: 1)
        headerFadeLayer.colors = [bg.cgColor, bg.withAlphaComponent(0).cgColor]
        headerFadeLayer.locations = [0.0, 1.0]
        fadeView.layer.addSublayer(headerFadeLayer)

        NSLayoutConstraint.activate([
            fadeView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            fadeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            fadeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            fadeView.heightAnchor.constraint(equalToConstant: 48),
        ])
    }

    private func setupNavBar() {
        // ── Center add button ──────────────────────────────────────────
        addButtonContainer = UIView()
        addButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        addButtonContainer.backgroundColor = UIColor(named: "ClayAccent")
        addButtonContainer.layer.cornerRadius = 30
        addButtonContainer.layer.shadowColor = UIColor.black.cgColor
        addButtonContainer.layer.shadowOpacity = 0.2
        addButtonContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        addButtonContainer.layer.shadowRadius = 8
        view.addSubview(addButtonContainer)

        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        let plusImage = UIImage(named: "icon-plus") ?? UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .medium))
        addButton.setImage(plusImage, for: .normal)
        addButton.tintColor = UIColor(named: "FogBackground")
        addButton.backgroundColor = .clear
        addButton.addTarget(self, action: #selector(addEventTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(islandButtonPressDown(_:)), for: .touchDown)
        addButton.addTarget(self, action: #selector(islandButtonPressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addButtonContainer.addSubview(addButton)

        // ── Left island: Home + Discover ──────────────────────────────
        leftIsland = makeIslandPill()
        view.addSubview(leftIsland)

        homeButton     = makeIslandButton(image: UIImage(named: "icon-house"),    action: #selector(homeTapped))
        discoverButton = makeIslandButton(image: UIImage(named: "icon-navigate"), action: #selector(discoverTapped))
        discoverButton.contentHorizontalAlignment = .fill
        discoverButton.contentVerticalAlignment = .fill
        discoverButton.imageView?.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            discoverButton.widthAnchor.constraint(equalToConstant: 29),
            discoverButton.heightAnchor.constraint(equalToConstant: 29),
        ])

        let leftStack = UIStackView(arrangedSubviews: [homeButton, discoverButton])
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        leftStack.axis = .horizontal
        leftStack.distribution = .equalSpacing
        leftStack.alignment = .center
        leftIsland.addSubview(leftStack)

        // ── Right island: Stats + Map ──────────────────────────────────
        rightIsland = makeIslandPill()
        view.addSubview(rightIsland)

        statsButton = makeIslandButton(image: UIImage(named: "icon-chart"), action: #selector(statsTapped))
        mapButton   = makeIslandButton(image: UIImage(named: "icon-map"),   action: #selector(mapTapped))

        let rightStack = UIStackView(arrangedSubviews: [statsButton, mapButton])
        rightStack.translatesAutoresizingMaskIntoConstraints = false
        rightStack.axis = .horizontal
        rightStack.distribution = .equalSpacing
        rightStack.alignment = .center
        rightIsland.addSubview(rightStack)

        // ── Layout ────────────────────────────────────────────────────
        NSLayoutConstraint.activate([
            // Add button: perfectly centered, same height as islands
            addButtonContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            addButtonContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButtonContainer.widthAnchor.constraint(equalToConstant: 60),
            addButtonContainer.heightAnchor.constraint(equalToConstant: 60),
            addButton.topAnchor.constraint(equalTo: addButtonContainer.topAnchor),
            addButton.bottomAnchor.constraint(equalTo: addButtonContainer.bottomAnchor),
            addButton.leadingAnchor.constraint(equalTo: addButtonContainer.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: addButtonContainer.trailingAnchor),

            // Left island: leading edge to screen edge, trailing to add button
            leftIsland.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            leftIsland.trailingAnchor.constraint(equalTo: addButtonContainer.leadingAnchor, constant: -10),
            leftIsland.centerYAnchor.constraint(equalTo: addButtonContainer.centerYAnchor),
            leftIsland.heightAnchor.constraint(equalToConstant: 60),
            leftStack.leadingAnchor.constraint(equalTo: leftIsland.leadingAnchor, constant: 22),
            leftStack.trailingAnchor.constraint(equalTo: leftIsland.trailingAnchor, constant: -22),
            leftStack.centerYAnchor.constraint(equalTo: leftIsland.centerYAnchor),

            // Right island: leading from add button, trailing to screen edge
            rightIsland.leadingAnchor.constraint(equalTo: addButtonContainer.trailingAnchor, constant: 10),
            rightIsland.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            rightIsland.centerYAnchor.constraint(equalTo: addButtonContainer.centerYAnchor),
            rightIsland.heightAnchor.constraint(equalToConstant: 60),
            rightStack.leadingAnchor.constraint(equalTo: rightIsland.leadingAnchor, constant: 22),
            rightStack.trailingAnchor.constraint(equalTo: rightIsland.trailingAnchor, constant: -22),
            rightStack.centerYAnchor.constraint(equalTo: rightIsland.centerYAnchor),
        ])

        updateIslandSelection()
    }

    private func makeIslandPill() -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor(named: "DeepPineInk")
        pill.layer.cornerRadius = 30
        pill.layer.shadowColor = UIColor.black.cgColor
        pill.layer.shadowOpacity = 0.2
        pill.layer.shadowOffset = CGSize(width: 0, height: 4)
        pill.layer.shadowRadius = 12
        return pill
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
        let target: UIView = (sender == addButton) ? addButtonContainer : sender
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            target.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        }
    }

    @objc private func islandButtonPressUp(_ sender: UIButton) {
        let target: UIView = (sender == addButton) ? addButtonContainer : sender
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: .allowUserInteraction) {
            target.transform = .identity
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

        if isBarHidden {
            isBarHidden = false
            navBarViews.forEach { $0.transform = .identity; $0.alpha = 1 }
        }

        mapView.alpha              = tab == .map      ? 1 : 0
        statsView.isHidden         = tab != .stats
        discoverView.isHidden      = tab != .discover
        tableView.isHidden         = tab != .home
        profileButtonView.isHidden = tab != .home
        greetingLabel.isHidden     = tab != .home
        dateLabel.isHidden         = tab != .home
        esriLabel.isHidden         = tab != .map
        headerFadeView?.isHidden   = tab != .home

        updateIslandSelection()
    }

    private func updateIslandSelection() {
        homeButton.setImage(UIImage(named: currentTab == .home
            ? "icon-house-filled" : "icon-house"), for: .normal)
        discoverButton.setImage(UIImage(named: currentTab == .discover
            ? "icon-navigate-filled" : "icon-navigate"), for: .normal)
        statsButton.setImage(UIImage(named: currentTab == .stats
            ? "icon-chart-filled" : "icon-chart"), for: .normal)
        mapButton.setImage(UIImage(named: currentTab == .map
            ? "icon-map-filled" : "icon-map"), for: .normal)

        homeButton.alpha     = currentTab == .home     ? 1.0 : 0.4
        discoverButton.alpha = currentTab == .discover ? 1.0 : 0.4
        statsButton.alpha    = currentTab == .stats    ? 1.0 : 0.4
        mapButton.alpha      = currentTab == .map      ? 1.0 : 0.4
    }

    @objc func homeTapped()     { switchTo(.home) }
    @objc func discoverTapped() { switchTo(.discover) }
    @objc func statsTapped()    { switchTo(.stats) }
    @objc func mapTapped()      { switchTo(.map) }

    @objc private func handleMapTap(_ gesture: UITapGestureRecognizer) {
        guard isBarHidden else { return }
        // Short delay lets double-tap zoom trigger regionWillChangeAnimated first,
        // so isMapMoving is true before we decide to show.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard let self, self.isBarHidden, !self.isMapMoving else { return }
            self.showBarAnimated()
        }
    }

    private func hideBarAnimated() {
        guard !isBarHidden else { return }
        isBarHidden = true
        let offscreen = CGAffineTransform(translationX: 0, y: 120)
        UIView.animate(withDuration: 0.52, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.6, options: [.curveEaseIn, .allowUserInteraction]) {
            self.navBarViews.forEach { $0.transform = offscreen; $0.alpha = 0 }
        }
    }

    private func showBarAnimated() {
        guard isBarHidden else { return }
        isBarHidden = false
        UIView.animate(withDuration: 0.52, delay: 0.04, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.6, options: [.curveEaseOut, .allowUserInteraction]) {
            self.navBarViews.forEach { $0.transform = .identity; $0.alpha = 1 }
        }
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let tileOverlay = overlay as? MKTileOverlay {
            return MKTileOverlayRenderer(tileOverlay: tileOverlay)
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard currentTab == .map else { return }
        isMapMoving = true
        hideBarAnimated()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        isMapMoving = false
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
            .font: UIFont.karla(.semibold, size: 12),
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
