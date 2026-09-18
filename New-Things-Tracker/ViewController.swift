//
//  ViewController.swift
//  New-Things-Tracker
//
//  Created by Lucas Waunn on 9/16/26.
//

import UIKit
import MapKit
import SwiftUI
import Combine

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

    // Live data pipeline
    private let photoManager    = PhotoMetadataManager()
    private let locationManager = LocationHistoryManager()
    private var cancellables    = Set<AnyCancellable>()
    private var hasRequestedPermissions = false
    private var sections: [(month: String, firsts: [First])] = []
    private var candidatesBySection: [[PlaceCandidate]] = []
    private var pendingCandidates: [PlaceCandidate] = []
    private weak var statsTotalLabel: UILabel?
    private weak var statsMonthLabel: UILabel?
    private weak var statsStreakLabel: UILabel?

    // Cycles through these colors for card backgrounds while real photos aren't shown
    private let cardColors: [(UIColor, UIColor)] = [
        (UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1), UIColor(red: 0.82, green: 0.70, blue: 0.63, alpha: 1)),
        (UIColor(red: 0.79, green: 0.87, blue: 0.82, alpha: 1), UIColor(red: 0.70, green: 0.80, blue: 0.74, alpha: 1)),
        (UIColor(red: 0.65, green: 0.75, blue: 0.85, alpha: 1), UIColor(red: 0.55, green: 0.65, blue: 0.78, alpha: 1)),
        (UIColor(red: 0.92, green: 0.85, blue: 0.72, alpha: 1), UIColor(red: 0.85, green: 0.78, blue: 0.65, alpha: 1)),
        (UIColor(red: 0.82, green: 0.78, blue: 0.90, alpha: 1), UIColor(red: 0.72, green: 0.68, blue: 0.82, alpha: 1)),
        (UIColor(red: 0.78, green: 0.88, blue: 0.84, alpha: 1), UIColor(red: 0.68, green: 0.80, blue: 0.76, alpha: 1)),
    ]

    private let cardDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM"; return f
    }()
    private let monthHeaderFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    override var prefersStatusBarHidden: Bool { true }
    override var canBecomeFirstResponder: Bool { true }

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

        // Rebuild home cards whenever the place-candidate list changes (initial load + geocoding updates)
        photoManager.$placeCandidates
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebuildSections() }
            .store(in: &cancellables)

        // Start off-screen for entrance animation
        let offscreen = CGAffineTransform(translationX: 0, y: 120)
        navBarViews.forEach { $0.transform = offscreen; $0.alpha = 0 }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()

        if !hasRequestedPermissions {
            hasRequestedPermissions = true
            locationManager.requestPermissionAndStart()
            photoManager.requestPermissionAndFetch()
        }
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
        greetingLabel.isUserInteractionEnabled = true
        greetingLabel.addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(debugLongPress(_:))))
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
        buildAndAttachStatsHeader()
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
        profileVC.placeCandidates = photoManager.placeCandidates
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
        let circular = UIGraphicsImageRenderer(size: size).image { _ in
            // Aspect-fill: scale so the shorter dimension fills the target, center-crop the longer one
            let scale  = max(size.width / image.size.width, size.height / image.size.height)
            let drawn  = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(x: (size.width - drawn.width) / 2, y: (size.height - drawn.height) / 2)
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).addClip()
            image.draw(in: CGRect(origin: origin, size: drawn))
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

    // MARK: - Stats header

    private func buildAndAttachStatsHeader() {
        let container = UIView()
        container.backgroundColor = .clear
        container.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 84)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.13)
        card.layer.cornerRadius = 16
        container.addSubview(card)

        func makeTile(value: String, caption: String) -> (UIView, UILabel) {
            let tile = UIView()
            tile.translatesAutoresizingMaskIntoConstraints = false
            let vLabel = UILabel()
            vLabel.translatesAutoresizingMaskIntoConstraints = false
            vLabel.text = value
            vLabel.font = UIFont.fraunces(.bold, size: 24)
            vLabel.textColor = UIColor(named: "FogBackground")
            vLabel.textAlignment = .center
            let nLabel = UILabel()
            nLabel.translatesAutoresizingMaskIntoConstraints = false
            nLabel.text = caption
            nLabel.font = UIFont.karla(.regular, size: 11)
            nLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.52)
            nLabel.textAlignment = .center
            tile.addSubview(vLabel)
            tile.addSubview(nLabel)
            NSLayoutConstraint.activate([
                vLabel.topAnchor.constraint(equalTo: tile.topAnchor),
                vLabel.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                nLabel.topAnchor.constraint(equalTo: vLabel.bottomAnchor, constant: 2),
                nLabel.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                nLabel.bottomAnchor.constraint(equalTo: tile.bottomAnchor),
            ])
            return (tile, vLabel)
        }

        let (totalTile, totalVal)  = makeTile(value: "—", caption: "total firsts")
        let (monthTile, monthVal)  = makeTile(value: "—", caption: "this month")
        let (streakTile, streakVal) = makeTile(value: "—", caption: "month streak")
        statsTotalLabel  = totalVal
        statsMonthLabel  = monthVal
        statsStreakLabel = streakVal

        let stack = UIStackView(arrangedSubviews: [totalTile, monthTile, streakTile])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])

        tableView.tableHeaderView = container
    }

    // MARK: - Review queue helpers

    private func centroidKey(_ coord: CLLocationCoordinate2D) -> String {
        "place_\(String(format: "%.3f", coord.latitude))_\(String(format: "%.3f", coord.longitude))"
    }

    private var reviewedPlaceKeys: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "reviewedPlaceKeys") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "reviewedPlaceKeys") }
    }

    private var reviewSectionOffset: Int { pendingCandidates.isEmpty ? 0 : 1 }

    private func monthStreak(from candidates: [PlaceCandidate]) -> Int {
        guard !candidates.isEmpty else { return 0 }
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month], from: Date())
        var streak = 0
        for _ in 0..<24 {
            let hasPlace = candidates.contains { c in
                let cc = calendar.dateComponents([.year, .month], from: c.firstVisitDate)
                return cc.year == comps.year && cc.month == comps.month
            }
            if hasPlace {
                streak += 1
                comps.month! -= 1
            } else { break }
        }
        return streak
    }

    private func updateStatsHeader(candidates: [PlaceCandidate]) {
        let calendar = Calendar.current
        let thisComps = calendar.dateComponents([.year, .month], from: Date())
        let thisMonthCount = candidates.filter {
            let c = calendar.dateComponents([.year, .month], from: $0.firstVisitDate)
            return c.year == thisComps.year && c.month == thisComps.month
        }.count
        let streak = monthStreak(from: candidates)
        statsTotalLabel?.text  = candidates.isEmpty ? "—" : "\(candidates.count)"
        statsMonthLabel?.text  = "\(thisMonthCount)"
        statsStreakLabel?.text = "\(max(streak, 0))"
    }

    private func makeHeaderView(_ text: String) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.attributedText = NSAttributedString(string: text, attributes: [
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

    private func showReviewAlert(for candidate: PlaceCandidate) {
        let name = candidate.placeName ?? "this place"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        let sheet = UIAlertController(
            title: "Was this a first?",
            message: "You visited \(name) on \(formatter.string(from: candidate.firstVisitDate)).",
            preferredStyle: .actionSheet
        )
        sheet.addAction(UIAlertAction(title: "Yes — it's a first!", style: .default) { [weak self] _ in
            self?.markReviewed(candidate)
        })
        sheet.addAction(UIAlertAction(title: "No, I've been here before", style: .default) { [weak self] _ in
            self?.markReviewed(candidate)
        })
        sheet.addAction(UIAlertAction(title: "Ask me later", style: .cancel))
        present(sheet, animated: true)
    }

    private func markReviewed(_ candidate: PlaceCandidate) {
        var keys = reviewedPlaceKeys
        keys.insert(centroidKey(candidate.centroid))
        reviewedPlaceKeys = keys
        pendingCandidates.removeAll { centroidKey($0.centroid) == centroidKey(candidate.centroid) }
        tableView.reloadData()
    }

    // MARK: - Home feed

    private func rebuildSections() {
        let candidates = photoManager.placeCandidates

        updateStatsHeader(candidates: candidates)

        let reviewed = reviewedPlaceKeys
        pendingCandidates = Array(candidates.filter { c in
            c.visitCount == 1 && !reviewed.contains(centroidKey(c.centroid))
        }.prefix(5))

        guard !candidates.isEmpty else {
            sections = []; candidatesBySection = []
            tableView.reloadData()
            return
        }

        let calendar = Calendar.current
        var monthOrder: [Date] = []
        var grouped: [Date: [PlaceCandidate]] = [:]

        for candidate in candidates {
            let comps = calendar.dateComponents([.year, .month], from: candidate.firstVisitDate)
            let key   = calendar.date(from: comps)!
            if grouped[key] == nil { grouped[key] = []; monthOrder.append(key) }
            grouped[key]!.append(candidate)
        }

        monthOrder.sort { $0 > $1 }

        var newSections: [(month: String, firsts: [First])] = []
        var newCandidatesBySection: [[PlaceCandidate]] = []
        var globalIndex = 0

        for key in monthOrder {
            let cands  = grouped[key]!
            let header = monthHeaderFormatter.string(from: key).uppercased()
            let firsts: [First] = cands.map { c in
                defer { globalIndex += 1 }
                let (large, small) = cardColors[globalIndex % cardColors.count]
                return First(
                    title:           c.placeName ?? "…",
                    location:        "\(c.visitCount) visit\(c.visitCount == 1 ? "" : "s")",
                    category:        "Place",
                    date:            cardDateFormatter.string(from: c.firstVisitDate),
                    duration:        "\(c.totalPhotoCount) photo\(c.totalPhotoCount == 1 ? "" : "s")",
                    photoCount:      0,
                    extraPhotos:     max(0, c.totalPhotoCount - 2),
                    largePhotoColor: large,
                    smallPhotoColor: small,
                    photoLocalIDs:   c.photoLocalIDs
                )
            }
            newSections.append((month: header, firsts: firsts))
            newCandidatesBySection.append(cands)
        }

        sections             = newSections
        candidatesBySection  = newCandidatesBySection
        tableView.reloadData()
    }

    // Shake device OR long-press the greeting label to open the data-wiring debug screen
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        presentDebugScreen()
    }

    @objc private func debugLongPress(_ gr: UILongPressGestureRecognizer) {
        guard gr.state == .began else { return }
        presentDebugScreen()
    }

    private func presentDebugScreen() {
        let host = UIHostingController(rootView: NavigationView { WiringTestView() })
        host.modalPresentationStyle = .pageSheet
        present(host, animated: true)
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
        sections.count + reviewSectionOffset
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 && !pendingCandidates.isEmpty { return pendingCandidates.count }
        return sections[section - reviewSectionOffset].firsts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 && !pendingCandidates.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: ReviewQueueCell.identifier, for: indexPath) as! ReviewQueueCell
            let c = pendingCandidates[indexPath.row]
            cell.configure(with: ReviewItem(
                label: c.placeName ?? "Somewhere new",
                date: cardDateFormatter.string(from: c.firstVisitDate),
                reason: "\(c.totalPhotoCount) photo\(c.totalPhotoCount == 1 ? "" : "s")"
            ))
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: FirstCardCell.identifier, for: indexPath) as! FirstCardCell
        cell.configure(with: sections[indexPath.section - reviewSectionOffset].firsts[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if section == 0 && !pendingCandidates.isEmpty { return makeHeaderView("NEEDS YOUR INPUT") }
        return makeHeaderView(sections[section - reviewSectionOffset].month)
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 && !pendingCandidates.isEmpty {
            showReviewAlert(for: pendingCandidates[indexPath.row])
            return
        }
        let s = indexPath.section - reviewSectionOffset
        guard s < candidatesBySection.count,
              indexPath.row < candidatesBySection[s].count else { return }
        let candidate = candidatesBySection[s][indexPath.row]
        let detailVC = PlaceDetailViewController(candidate: candidate)
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(detailVC, animated: true)
    }
}
