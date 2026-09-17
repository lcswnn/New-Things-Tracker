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
    private var profileButtonContainer: UIView!
    private var mapView: MKMapView!
    private var statsView: UIView!
    private var discoverView: UIView!
    private var discoverVC: DiscoverViewController!
    private var statsVC: StatsViewController!
    private var islandBar: UIView!
    private var tableView: UITableView!
    private var homeButton: UIButton!
    private var discoverButton: UIButton!
    private var statsButton: UIButton!
    private var mapButton: UIButton!
    private var addButton: UIButton!
    private var addButtonContainer: UIView!

    private var navBarViews: [UIView] { [islandBar, addButtonContainer] }
    private var greetingLabel: UILabel!
    private var dateLabel: UILabel!
    private var esriLabel: UILabel!
    private weak var headerFadeView: UIView?
    private var isBarHidden = false
    private var isMapMoving = false
    private var profileImage: UIImage?

    override var prefersStatusBarHidden: Bool { true }

    private let reviewItems: [ReviewItem] = [
        ReviewItem(label: "Green Mill Cocktail Lounge", date: "Today",  reason: "Confirm label"),
        ReviewItem(label: "Unknown Venue",               date: "Sep 6", reason: "Possible duplicate of Randolph Street Market"),
    ]

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
        setupHeaderLine()
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
        profileButtonView.tintColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.75)
        profileButtonView.backgroundColor = .clear
        profileButtonView.addTarget(self, action: #selector(profileTapped), for: .touchUpInside)
        profileButtonView.addTarget(self, action: #selector(islandButtonPressDown(_:)), for: .touchDown)
        profileButtonView.addTarget(self, action: #selector(islandButtonPressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        profileButtonContainer = profileButtonView  // animate the button itself
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
        tableView.register(FirstCardCell.self,   forCellReuseIdentifier: FirstCardCell.identifier)
        tableView.register(ReviewQueueCell.self, forCellReuseIdentifier: ReviewQueueCell.identifier)
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

    private func setupHeaderLine() {
        let line = UIView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.isUserInteractionEnabled = false
        line.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.20)
        headerFadeView = line
        view.insertSubview(line, aboveSubview: tableView)

        NSLayoutConstraint.activate([
            line.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            line.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            line.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            line.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func setupNavBar() {
        setupIslandBar()
        setupAddButton()
    }

    private func setupIslandBar() {
        // islandBar is a clear shadow-casting container; the blur lives inside it
        islandBar = UIView()
        islandBar.translatesAutoresizingMaskIntoConstraints = false
        islandBar.backgroundColor = .clear
        islandBar.layer.shadowColor = UIColor.black.cgColor
        islandBar.layer.shadowOpacity = 0.18
        islandBar.layer.shadowOffset = CGSize(width: 0, height: 6)
        islandBar.layer.shadowRadius = 18
        // Explicit path so the shadow renders on a clear background
        islandBar.layer.shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 290, height: 60), cornerRadius: 30).cgPath
        view.addSubview(islandBar)

        NSLayoutConstraint.activate([
            islandBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            islandBar.centerXAnchor.constraint(equalTo: view.centerXAnchor, constant: -33),
            islandBar.heightAnchor.constraint(equalToConstant: 60),
            islandBar.widthAnchor.constraint(equalToConstant: 290),
        ])

        // Liquid Glass pill tinted dark so it pops against any background
        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.tintColor = UIColor(named: "DeepPineInk")
        let glass = UIVisualEffectView(effect: glassEffect)
        glass.translatesAutoresizingMaskIntoConstraints = false
        glass.layer.cornerRadius = 30
        glass.layer.masksToBounds = true
        islandBar.addSubview(glass)
        NSLayoutConstraint.activate([
            glass.topAnchor.constraint(equalTo: islandBar.topAnchor),
            glass.bottomAnchor.constraint(equalTo: islandBar.bottomAnchor),
            glass.leadingAnchor.constraint(equalTo: islandBar.leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: islandBar.trailingAnchor),
        ])

        homeButton     = makeIslandButton(image: UIImage(named: "icon-house"),    action: #selector(homeTapped))
        discoverButton = makeIslandButton(image: UIImage(named: "icon-navigate"), action: #selector(discoverTapped))
        statsButton    = makeIslandButton(image: UIImage(named: "icon-chart"),    action: #selector(statsTapped))
        mapButton      = makeIslandButton(image: UIImage(named: "icon-map"),      action: #selector(mapTapped))

        discoverButton.contentHorizontalAlignment = .fill
        discoverButton.contentVerticalAlignment = .fill
        discoverButton.imageView?.contentMode = .scaleAspectFit
        NSLayoutConstraint.activate([
            discoverButton.widthAnchor.constraint(equalToConstant: 29),
            discoverButton.heightAnchor.constraint(equalToConstant: 29),
        ])

        // Buttons go into contentView so touches aren't eaten by the effect view
        let stack = UIStackView(arrangedSubviews: [homeButton, discoverButton, statsButton, mapButton])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        glass.contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: glass.contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: glass.contentView.trailingAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: glass.contentView.centerYAnchor),
        ])

        updateIslandSelection()
    }

    private func setupAddButton() {
        addButtonContainer = UIView()
        addButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        addButtonContainer.backgroundColor = .clear
        addButtonContainer.layer.cornerRadius = 27
        addButtonContainer.layer.shadowColor = UIColor.black.cgColor
        addButtonContainer.layer.shadowOpacity = 0.18
        addButtonContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        addButtonContainer.layer.shadowRadius = 10
        addButtonContainer.layer.shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 54, height: 54), cornerRadius: 27).cgPath
        view.addSubview(addButtonContainer)

        // Orange-tinted Liquid Glass circle
        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.tintColor = UIColor(named: "ClayAccent")
        let addGlass = UIVisualEffectView(effect: glassEffect)
        addGlass.translatesAutoresizingMaskIntoConstraints = false
        addGlass.layer.cornerRadius = 27
        addGlass.layer.masksToBounds = true
        addButtonContainer.addSubview(addGlass)

        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        let plusImage = UIImage(named: "icon-plus") ?? UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium))
        addButton.setImage(plusImage, for: .normal)
        addButton.tintColor = UIColor(named: "DeepPineInk")
        addButton.backgroundColor = .clear
        addButton.addTarget(self, action: #selector(addEventTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(islandButtonPressDown(_:)), for: .touchDown)
        addButton.addTarget(self, action: #selector(islandButtonPressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        addGlass.contentView.addSubview(addButton)

        NSLayoutConstraint.activate([
            addButtonContainer.centerYAnchor.constraint(equalTo: islandBar.centerYAnchor),
            addButtonContainer.leadingAnchor.constraint(equalTo: islandBar.trailingAnchor, constant: 12),
            addButtonContainer.widthAnchor.constraint(equalToConstant: 54),
            addButtonContainer.heightAnchor.constraint(equalToConstant: 54),

            addGlass.topAnchor.constraint(equalTo: addButtonContainer.topAnchor),
            addGlass.bottomAnchor.constraint(equalTo: addButtonContainer.bottomAnchor),
            addGlass.leadingAnchor.constraint(equalTo: addButtonContainer.leadingAnchor),
            addGlass.trailingAnchor.constraint(equalTo: addButtonContainer.trailingAnchor),

            addButton.topAnchor.constraint(equalTo: addGlass.contentView.topAnchor),
            addButton.bottomAnchor.constraint(equalTo: addGlass.contentView.bottomAnchor),
            addButton.leadingAnchor.constraint(equalTo: addGlass.contentView.leadingAnchor),
            addButton.trailingAnchor.constraint(equalTo: addGlass.contentView.trailingAnchor),
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
        let target: UIView
        switch sender {
        case addButton:         target = addButtonContainer
        case profileButtonView: target = profileButtonContainer
        default:                target = sender
        }
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseIn, .allowUserInteraction]) {
            target.transform = CGAffineTransform(scaleX: 0.75, y: 0.75)
        }
    }

    @objc private func islandButtonPressUp(_ sender: UIButton) {
        let target: UIView
        switch sender {
        case addButton:         target = addButtonContainer
        case profileButtonView: target = profileButtonContainer
        default:                target = sender
        }
        UIView.animate(withDuration: 0.8, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: .allowUserInteraction) {
            target.transform = .identity
        }
    }

    @objc func profileTapped() {
        let profileVC = ProfileViewController()
        profileVC.delegate = self
        profileVC.initialImage = profileImage
        profileVC.modalPresentationStyle = .pageSheet
        if let sheet = profileVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(profileVC, animated: true)
    }

    private func applyProfilePhoto(_ image: UIImage) {
        profileImage = image
        let size = CGSize(width: 40, height: 40)
        let circular = UIGraphicsImageRenderer(size: size).image { ctx in
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(.alwaysOriginal)
        profileButtonView.setImage(circular, for: .normal)
        profileButtonView.imageView?.layer.cornerRadius = 20
        profileButtonView.imageView?.clipsToBounds = true
        profileButtonView.layer.cornerRadius = 20
        profileButtonView.clipsToBounds = true
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

        homeButton.alpha     = currentTab == .home     ? 1.0 : 0.35
        discoverButton.alpha = currentTab == .discover ? 1.0 : 0.35
        statsButton.alpha    = currentTab == .stats    ? 1.0 : 0.35
        mapButton.alpha      = currentTab == .map      ? 1.0 : 0.35
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
        // Reverse stagger: add button leaves first, island bar follows
        let delays: [Double] = [0, 0.06]
        for (v, delay) in zip(navBarViews.reversed(), delays) {
            UIView.animate(withDuration: 0.48, delay: delay, usingSpringWithDamping: 0.88, initialSpringVelocity: 0.8, options: .allowUserInteraction) {
                v.transform = offscreen
                v.alpha = 0
            }
        }
    }

    private func showBarAnimated() {
        guard isBarHidden else { return }
        isBarHidden = false
        // Same spring as viewDidAppear entrance
        let delays: [Double] = [0.06, 0.12]
        for (v, delay) in zip(navBarViews, delays) {
            UIView.animate(withDuration: 0.52, delay: delay, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.6, options: [.curveEaseOut, .allowUserInteraction]) {
                v.transform = .identity
                v.alpha = 1
            }
        }
    }
}

extension ViewController: ProfileViewControllerDelegate {
    func profileViewController(_ vc: ProfileViewController, didUpdatePhoto image: UIImage) {
        applyProfilePhoto(image)
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
        sections.count + 1   // section 0 = review queue
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? reviewItems.count : sections[section - 1].firsts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: ReviewQueueCell.identifier, for: indexPath) as! ReviewQueueCell
            cell.configure(with: reviewItems[indexPath.row])
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: FirstCardCell.identifier, for: indexPath) as! FirstCardCell
        cell.configure(with: sections[indexPath.section - 1].firsts[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        container.backgroundColor = .clear

        if section == 0 {
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.attributedText = NSAttributedString(string: "NEEDS REVIEW", attributes: [
                .font: UIFont.karla(.bold, size: 14),
                .foregroundColor: UIColor(named: "FogBackground") ?? UIColor.white,
                .kern: 1.8,
            ])
            container.addSubview(label)

            let badge = UIView()
            badge.translatesAutoresizingMaskIntoConstraints = false
            badge.backgroundColor = UIColor(named: "ClayAccent")
            badge.layer.cornerRadius = 10
            container.addSubview(badge)

            let badgeLabel = UILabel()
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            badgeLabel.text = "\(reviewItems.count)"
            badgeLabel.font = UIFont.karla(.bold, size: 12)
            badgeLabel.textColor = UIColor(named: "FogBackground")
            badge.addSubview(badgeLabel)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),

                badge.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
                badge.centerYAnchor.constraint(equalTo: label.centerYAnchor),

                badgeLabel.topAnchor.constraint(equalTo: badge.topAnchor, constant: 3),
                badgeLabel.bottomAnchor.constraint(equalTo: badge.bottomAnchor, constant: -3),
                badgeLabel.leadingAnchor.constraint(equalTo: badge.leadingAnchor, constant: 8),
                badgeLabel.trailingAnchor.constraint(equalTo: badge.trailingAnchor, constant: -8),
            ])
            return container
        }

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedText = NSAttributedString(string: sections[section - 1].month, attributes: [
            .font: UIFont.karla(.semibold, size: 12),
            .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.7) ?? UIColor.white,
            .kern: 1.5,
        ])
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }
}
