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
import SwiftData
import Photos


class ViewController: UIViewController {

    private enum Tab { case home, discover, stats, map }
    private var currentTab: Tab = .home

    // Home feed table structure. FeedItem.first is keyed by the Place's real PersistentIdentifier.
    // Explicitly nonisolated: UITableViewDiffableDataSource requires Sendable section/item types,
    // but the app target's SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor would otherwise make these
    // nested types MainActor-isolated (and therefore not Sendable).
    private nonisolated enum FeedSection: Hashable {
        case review
        case mostRecent
        case month(Date)
    }

    private nonisolated enum FeedItem: Hashable {
        case reviewCarousel
        case first(PersistentIdentifier)
    }

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
    private weak var headerFadeView: UIView?
    private var isBarHidden = false
    private var isMapMoving = false
    private var profileImage: UIImage?

    // Set by SceneDelegate.scene(_:willConnectTo:) before viewDidAppear runs. Never read before
    // viewDidAppear — UIKit can call viewDidLoad before scene(_:willConnectTo:) runs.
    var environment: AppEnvironment!

    // Live data pipeline
    private let locationManager = LocationHistoryManager()
    private var cancellables    = Set<AnyCancellable>()
    private var hasRequestedPermissions = false
    private var dataSource: UITableViewDiffableDataSource<FeedSection, FeedItem>!
    private var viewModelsByID: [PersistentIdentifier: FirstCardViewModel] = [:]
    private var placesByID: [PersistentIdentifier: PlaceSummary] = [:]
    private var mostRecentID: PersistentIdentifier?
    private var pendingReviewItems: [ReviewItem] = []
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
    private let reviewDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE d MMM 'at' h:mm a"; return f
    }()

    override var prefersStatusBarHidden: Bool { true }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        navigationController?.navigationBar.isHidden = true

        setupMapView()
        prewarmMapRegion()
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
        becomeFirstResponder()

        if !hasRequestedPermissions {
            hasRequestedPermissions = true
            subscribeToStore()
            locationManager.onVisit = { [weak self] visit in
                self?.environment.store.recordVisit(visit)
            }
            locationManager.requestPermissionAndStart()
            requestPhotoAccessAndRunBackfill()
        }
        let delays: [Double] = [0.06, 0.12, 0.06]
        for (view, delay) in zip(navBarViews, delays) {
            UIView.animate(withDuration: 0.52, delay: delay, usingSpringWithDamping: 0.78, initialSpringVelocity: 0.6, options: [.curveEaseOut, .allowUserInteraction]) {
                view.transform = .identity
                view.alpha = 1
            }
        }
    }

    // Rebuilds the home feed whenever the store's places or pending review queue changes (initial
    // load, and after every backfill run). One diff per commit, not one reload per resolved place.
    private func subscribeToStore() {
        environment.store.$places
            .combineLatest(environment.store.$pendingReview)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] places, _ in
                self?.applySnapshot()
                self?.discoverVC.updateVisitedCoordinates(places.map { $0.centroid })
            }
            .store(in: &cancellables)
    }

    // FirstsImporter reads PHAsset directly, so the system permission prompt still has to happen
    // here before the first backfill can see anything.
    private func requestPhotoAccessAndRunBackfill() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            Task { await environment.store.runBackfill() }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                guard status == .authorized || status == .limited else { return }
                Task { @MainActor in await self?.environment.store.runBackfill() }
            }
        default:
            break
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
        mapView.alpha = 0.001          // non-zero so MapKit loads tiles in the background
        mapView.isUserInteractionEnabled = false
        mapView.delegate = self
        mapView.showsCompass = false
        mapView.showsScale = false

        // Muted standard style — clean, low-distraction, loads instantly from system cache
        let config = MKStandardMapConfiguration(emphasisStyle: .muted)
        config.showsTraffic = false
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config

        let mapTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(_:)))
        mapView.addGestureRecognizer(mapTapGesture)

        view.addSubview(mapView)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    // Sets the map's initial region from the saved home coordinate so tiles at the
    // user's local zoom level start loading before they ever tap the map tab.
    private func prewarmMapRegion() {
        let lat = UserDefaults.standard.double(forKey: "homeLatitude")
        let lon = UserDefaults.standard.double(forKey: "homeLongitude")
        guard lat != 0 || lon != 0 else { return }
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            latitudinalMeters: 15_000, longitudinalMeters: 15_000
        )
        mapView.setRegion(region, animated: false)
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
        tableView.register(FirstCardCell.self,    forCellReuseIdentifier: FirstCardCell.identifier)
        tableView.register(PastFirstRowCell.self, forCellReuseIdentifier: PastFirstRowCell.identifier)
        tableView.register(ReviewCardCell.self,   forCellReuseIdentifier: ReviewCardCell.identifier)
        tableView.delegate = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        configureDataSource()
        buildAndAttachStatsHeader()
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<FeedSection, FeedItem>(tableView: tableView) { [weak self] tableView, indexPath, item in
            guard let self else { return UITableViewCell() }
            switch item {
            case .reviewCarousel:
                let cell = tableView.dequeueReusableCell(withIdentifier: ReviewCardCell.identifier, for: indexPath) as! ReviewCardCell
                cell.configure(with: self.pendingReviewItems, delegate: self)
                return cell
            case .first(let key):
                guard let viewModel = self.viewModelsByID[key] else { return UITableViewCell() }
                if key == self.mostRecentID {
                    let cell = tableView.dequeueReusableCell(withIdentifier: FirstCardCell.identifier, for: indexPath) as! FirstCardCell
                    cell.configure(with: viewModel)
                    return cell
                } else {
                    let cell = tableView.dequeueReusableCell(withIdentifier: PastFirstRowCell.identifier, for: indexPath) as! PastFirstRowCell
                    cell.configure(with: viewModel)
                    return cell
                }
            }
        }
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
        profileVC.placeCandidates = environment.store.places
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

        mapView.alpha                    = tab == .map ? 1.0 : 0.001
        mapView.isUserInteractionEnabled = tab == .map
        statsView.isHidden         = tab != .stats
        discoverView.isHidden      = tab != .discover
        tableView.isHidden         = tab != .home
        profileButtonView.isHidden = tab != .home
        greetingLabel.isHidden     = tab != .home
        dateLabel.isHidden         = tab != .home
        headerFadeView?.isHidden   = tab != .home

        if tab == .discover {
            discoverVC.refreshIfNeeded()
        }
        if tab == .map {
            refreshCoarseFirstAnnotations()
        }

        updateIslandSelection()
    }

    // Neighborhood/city/region/country Firsts as map pins — the place-level feed on Home stays
    // place-only, so this is the only place coarse Firsts are surfaced at all.
    private func refreshCoarseFirstAnnotations() {
        mapView.removeAnnotations(mapView.annotations)
        let annotations = environment.store.coarseFirsts().map { first -> MKPointAnnotation in
            let annotation = MKPointAnnotation()
            annotation.coordinate = first.coordinate
            annotation.title = first.title
            annotation.subtitle = first.level.rawValue.capitalized
            return annotation
        }
        mapView.addAnnotations(annotations)
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

    // Stable per-place color index so cards don't reshuffle colors whenever the sorted places
    // list changes (an FNV-1a hash of the place's canonical key, not the array index).
    private func stableColorIndex(for key: String) -> Int {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Int(hash % UInt64(cardColors.count))
    }

    private func monthStreak(from places: [PlaceSummary]) -> Int {
        guard !places.isEmpty else { return 0 }
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month], from: Date())
        var streak = 0
        for _ in 0..<24 {
            let hasPlace = places.contains { p in
                let pc = calendar.dateComponents([.year, .month], from: p.firstVisitDate)
                return pc.year == comps.year && pc.month == comps.month
            }
            if hasPlace {
                streak += 1
                comps.month! -= 1
            } else { break }
        }
        return streak
    }

    private func updateStatsHeader(places: [PlaceSummary]) {
        let calendar = Calendar.current
        let thisComps = calendar.dateComponents([.year, .month], from: Date())
        let thisMonthCount = places.filter {
            let p = calendar.dateComponents([.year, .month], from: $0.firstVisitDate)
            return p.year == thisComps.year && p.month == thisComps.month
        }.count
        let streak = monthStreak(from: places)
        statsTotalLabel?.text  = places.isEmpty ? "—" : "\(places.count)"
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

    // MARK: - Home feed

    private func applySnapshot(animatingDifferences: Bool = true) {
        let places = environment.store.places
        let pending = environment.store.pendingReview

        updateStatsHeader(places: places)

        pendingReviewItems = pending.map { candidate in
            ReviewItem(
                id: candidate.id,
                label: candidate.placeName,
                date: reviewDateFormatter.string(from: candidate.firstVisitDate),
                reason: "\(candidate.totalPhotoCount) photo\(candidate.totalPhotoCount == 1 ? "" : "s")",
                photoLocalIDs: candidate.photoLocalIDs
            )
        }

        var snapshot = NSDiffableDataSourceSnapshot<FeedSection, FeedItem>()
        if !pending.isEmpty {
            snapshot.appendSections([.review])
            snapshot.appendItems([.reviewCarousel], toSection: .review)
        }

        viewModelsByID.removeAll()
        placesByID.removeAll()
        mostRecentID = nil

        guard !places.isEmpty else {
            dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
            return
        }

        // Most recent first up top as the big card; everything older is grouped by month below.
        let sortedPlaces = places.sorted { $0.firstVisitDate > $1.firstVisitDate }

        for summary in sortedPlaces {
            placesByID[summary.id] = summary
            let (large, small) = cardColors[stableColorIndex(for: summary.key)]
            viewModelsByID[summary.id] = FirstCardViewModel(
                title:           summary.placeName,
                location:        "\(summary.visitCount) visit\(summary.visitCount == 1 ? "" : "s")",
                category:        "Place",
                date:            cardDateFormatter.string(from: summary.firstVisitDate),
                duration:        "\(summary.totalPhotoCount) photo\(summary.totalPhotoCount == 1 ? "" : "s")",
                photoCount:      0,
                extraPhotos:     max(0, summary.totalPhotoCount - 2),
                largePhotoColor: large,
                smallPhotoColor: small,
                photoLocalIDs:   summary.photoLocalIDs
            )
        }

        let mostRecent = sortedPlaces[0]
        mostRecentID = mostRecent.id
        snapshot.appendSections([.mostRecent])
        snapshot.appendItems([.first(mostRecent.id)], toSection: .mostRecent)

        let pastPlaces = Array(sortedPlaces.dropFirst())
        let calendar = Calendar.current
        var monthOrder: [Date] = []
        var grouped: [Date: [PlaceSummary]] = [:]

        for summary in pastPlaces {
            let comps = calendar.dateComponents([.year, .month], from: summary.firstVisitDate)
            let key   = calendar.date(from: comps)!
            if grouped[key] == nil { grouped[key] = []; monthOrder.append(key) }
            grouped[key]!.append(summary)
        }

        monthOrder.sort { $0 > $1 }
        for monthKey in monthOrder {
            let section = FeedSection.month(monthKey)
            snapshot.appendSections([section])
            snapshot.appendItems(grouped[monthKey]!.map { .first($0.id) }, toSection: section)
        }

        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)
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
        let host = UIHostingController(rootView: NavigationView { WiringTestView(environment: environment) })
        host.modalPresentationStyle = .pageSheet
        present(host, animated: true)
    }
}

extension ViewController: ProfileViewControllerDelegate {
    func profileViewController(_ vc: ProfileViewController, didUpdatePhoto image: UIImage) {
        applyProfilePhoto(image)
    }
}

extension ViewController: ReviewCardCellDelegate {
    func reviewCardCell(_ cell: ReviewCardCell, didAnswerYesFor id: PersistentIdentifier) {
        Task { await environment.store.confirmTopCandidate(forStayID: id) }
    }

    func reviewCardCell(_ cell: ReviewCardCell, didAnswerNoFor id: PersistentIdentifier) {
        presentReviewSheet(for: id)
    }

    func reviewCardCell(_ cell: ReviewCardCell, didTapCardFor id: PersistentIdentifier) {
        presentReviewSheet(for: id)
    }

    private func presentReviewSheet(for stayID: PersistentIdentifier) {
        guard let candidate = environment.store.pendingReview.first(where: { $0.id == stayID }) else { return }
        let sheet = PlaceReviewSheet(candidate: candidate, store: environment.store)
        sheet.modalPresentationStyle = .pageSheet
        if let presentation = sheet.sheetPresentationController {
            presentation.detents = [.medium(), .large()]
            presentation.prefersGrabberVisible = true
            presentation.preferredCornerRadius = 24
        }
        present(sheet, animated: true)
    }
}

extension ViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        guard currentTab == .map else { return }
        isMapMoving = true
        hideBarAnimated()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        isMapMoving = false
    }
}

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let dataSource, section < dataSource.snapshot().sectionIdentifiers.count else { return nil }
        switch dataSource.snapshot().sectionIdentifiers[section] {
        case .review:      return makeHeaderView("NEEDS YOUR INPUT")
        case .mostRecent:  return makeHeaderView("MOST RECENT 'FIRST'")
        case .month(let date): return makeHeaderView(monthHeaderFormatter.string(from: date).uppercased())
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat { 36 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .reviewCarousel:
            return
        case .first(let id):
            presentPlaceDetail(for: id)
        }
    }

    private func presentPlaceDetail(for placeID: PersistentIdentifier) {
        let detailVC = PlaceDetailViewController(placeID: placeID, store: environment.store)
        detailVC.modalPresentationStyle = .pageSheet
        if let sheet = detailVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(detailVC, animated: true)
    }
}
