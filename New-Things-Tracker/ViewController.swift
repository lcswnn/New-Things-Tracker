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
        case footer
    }

    private nonisolated enum FeedItem: Hashable {
        case review(PersistentIdentifier)
        case first(PersistentIdentifier)
        case footer
    }

    // Island bar sits 60pt tall + 16pt gap above safeAreaLayoutGuide.bottomAnchor
    private let islandClearance: CGFloat = 60 + 16 + 10

    private var profileButtonView: UIButton!
    private var profileButtonContainer: UIView!
    private var mapView: MKMapView!
    private var mapTitleLabel: UILabel!
    private var mapInfoCard: UIView!
    private var mapPinsCitiesLabel: UILabel!
    private var mapRecentThumbView: UIView!
    private var mapRecentImageView: UIImageView!
    private var mapRecentTitleLabel: UILabel!
    private var mapRecentSubtitleLabel: UILabel!
    private var mapRecentRequestID: PHImageRequestID?
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
    private var footerTotal = 0
    private var footerThisYear = 0
    private var footerCities = 0

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
    private let mapRecentDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
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
            statsVC.environment = environment
            statsVC.refresh()
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
                self?.updateMapInfoCard()
                self?.statsVC.refresh()
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
        mapView.layer.cornerRadius = 28
        mapView.clipsToBounds = true

        // Muted standard style — clean, low-distraction, loads instantly from system cache
        let config = MKStandardMapConfiguration(emphasisStyle: .muted)
        config.showsTraffic = false
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config

        view.addSubview(mapView)

        mapTitleLabel = UILabel()
        mapTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        mapTitleLabel.text = "Map"
        mapTitleLabel.font = UIFont.frauncesBoldItalic(size: 28)
        mapTitleLabel.textColor = UIColor(named: "FogBackground")
        mapTitleLabel.textAlignment = .center
        mapTitleLabel.isHidden = true
        view.addSubview(mapTitleLabel)

        setupMapInfoCard()

        NSLayoutConstraint.activate([
            mapTitleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            mapTitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            mapTitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            mapView.topAnchor.constraint(equalTo: mapTitleLabel.bottomAnchor, constant: 16),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapView.bottomAnchor.constraint(equalTo: mapInfoCard.topAnchor, constant: -16),
        ])
    }

    private func setupMapInfoCard() {
        mapInfoCard = UIView()
        mapInfoCard.translatesAutoresizingMaskIntoConstraints = false
        mapInfoCard.backgroundColor = UIColor(named: "FogBackground")
        mapInfoCard.layer.cornerRadius = 22
        mapInfoCard.layer.shadowColor = UIColor.black.cgColor
        mapInfoCard.layer.shadowOpacity = 0.15
        mapInfoCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        mapInfoCard.layer.shadowRadius = 12
        mapInfoCard.isHidden = true
        view.addSubview(mapInfoCard)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Your firsts map"
        titleLabel.font = UIFont.fraunces(.bold, size: 18)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        mapInfoCard.addSubview(titleLabel)

        let pinsLabel = UILabel()
        pinsLabel.translatesAutoresizingMaskIntoConstraints = false
        pinsLabel.font = UIFont.karla(.regular, size: 13)
        pinsLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50)
        mapInfoCard.addSubview(pinsLabel)
        mapPinsCitiesLabel = pinsLabel

        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.10)
        mapInfoCard.addSubview(divider)

        let thumb = UIView()
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.layer.cornerRadius = 12
        thumb.clipsToBounds = true
        mapInfoCard.addSubview(thumb)
        mapRecentThumbView = thumb

        let thumbImage = UIImageView()
        thumbImage.translatesAutoresizingMaskIntoConstraints = false
        thumbImage.contentMode = .scaleAspectFill
        thumbImage.clipsToBounds = true
        thumb.addSubview(thumbImage)
        mapRecentImageView = thumbImage

        let recentTitle = UILabel()
        recentTitle.translatesAutoresizingMaskIntoConstraints = false
        recentTitle.font = UIFont.karla(.semibold, size: 15)
        recentTitle.textColor = UIColor(named: "DeepPineInk")
        mapInfoCard.addSubview(recentTitle)
        mapRecentTitleLabel = recentTitle

        let recentSubtitle = UILabel()
        recentSubtitle.translatesAutoresizingMaskIntoConstraints = false
        recentSubtitle.font = UIFont.karla(.regular, size: 13)
        recentSubtitle.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50)
        mapInfoCard.addSubview(recentSubtitle)
        mapRecentSubtitleLabel = recentSubtitle

        NSLayoutConstraint.activate([
            mapInfoCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            mapInfoCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            mapInfoCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -(islandClearance + 6)),

            titleLabel.topAnchor.constraint(equalTo: mapInfoCard.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: mapInfoCard.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(equalTo: mapInfoCard.trailingAnchor, constant: -18),

            pinsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            pinsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pinsLabel.trailingAnchor.constraint(equalTo: mapInfoCard.trailingAnchor, constant: -18),

            divider.topAnchor.constraint(equalTo: pinsLabel.bottomAnchor, constant: 14),
            divider.leadingAnchor.constraint(equalTo: mapInfoCard.leadingAnchor, constant: 18),
            divider.trailingAnchor.constraint(equalTo: mapInfoCard.trailingAnchor, constant: -18),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            thumb.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),
            thumb.leadingAnchor.constraint(equalTo: mapInfoCard.leadingAnchor, constant: 18),
            thumb.widthAnchor.constraint(equalToConstant: 48),
            thumb.heightAnchor.constraint(equalToConstant: 48),
            thumb.bottomAnchor.constraint(equalTo: mapInfoCard.bottomAnchor, constant: -18),

            thumbImage.topAnchor.constraint(equalTo: thumb.topAnchor),
            thumbImage.bottomAnchor.constraint(equalTo: thumb.bottomAnchor),
            thumbImage.leadingAnchor.constraint(equalTo: thumb.leadingAnchor),
            thumbImage.trailingAnchor.constraint(equalTo: thumb.trailingAnchor),

            recentTitle.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 12),
            recentTitle.topAnchor.constraint(equalTo: thumb.topAnchor, constant: -2),
            recentTitle.trailingAnchor.constraint(equalTo: mapInfoCard.trailingAnchor, constant: -18),

            recentSubtitle.leadingAnchor.constraint(equalTo: recentTitle.leadingAnchor),
            recentSubtitle.topAnchor.constraint(equalTo: recentTitle.bottomAnchor, constant: 2),
            recentSubtitle.trailingAnchor.constraint(equalTo: mapInfoCard.trailingAnchor, constant: -18),
        ])
    }

    // Refreshes the "Your firsts map" card's pin/city counts and most-recent-first preview.
    private func updateMapInfoCard() {
        guard mapInfoCard != nil else { return }
        let places = environment.store.places
        let cities = Set(places.compactMap { environment.store.place(for: $0.id)?.city }).count
        mapPinsCitiesLabel.text = "\(places.count) pin\(places.count == 1 ? "" : "s") · \(cities) cit\(cities == 1 ? "y" : "ies")"

        if let id = mapRecentRequestID { PHImageManager.default().cancelImageRequest(id); mapRecentRequestID = nil }
        mapRecentImageView.image = nil

        guard let mostRecent = places.max(by: { $0.firstVisitDate < $1.firstVisitDate }) else {
            mapRecentTitleLabel.text = "No firsts yet"
            mapRecentSubtitleLabel.text = "Get out there and explore!"
            mapRecentThumbView.backgroundColor = UIColor(named: "DustySage")?.withAlphaComponent(0.3)
            return
        }

        mapRecentTitleLabel.text = mostRecent.placeName
        mapRecentSubtitleLabel.text = "first visited \(mapRecentDateFormatter.string(from: mostRecent.firstVisitDate))"
        mapRecentThumbView.backgroundColor = cardColors[stableColorIndex(for: mostRecent.key)].0

        guard let localID = mostRecent.photoLocalIDs.first,
              let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil).firstObject else { return }
        let scale = traitCollection.displayScale
        let pixelSize = CGSize(width: 48 * scale, height: 48 * scale)
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        opts.resizeMode = .fast
        mapRecentRequestID = PHImageManager.default().requestImage(
            for: asset, targetSize: pixelSize, contentMode: .aspectFill, options: opts
        ) { [weak self] image, _ in
            DispatchQueue.main.async { self?.mapRecentImageView.image = image }
        }
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
        greetingLabel.font = UIFont.frauncesBoldItalic(size: 28)
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
        let timeOfDay: String
        switch hour {
        case 0..<12: timeOfDay = "Good morning"
        case 12..<17: timeOfDay = "Good afternoon"
        default:      timeOfDay = "Good evening"
        }
        return "\(timeOfDay), \(UIDevice.current.name.components(separatedBy: "'").first ?? "there")"
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
        tableView.register(FirstCardCell.self,       forCellReuseIdentifier: FirstCardCell.identifier)
        tableView.register(PastFirstRowCell.self,    forCellReuseIdentifier: PastFirstRowCell.identifier)
        tableView.register(HomeStatsFooterCell.self, forCellReuseIdentifier: HomeStatsFooterCell.identifier)
        tableView.delegate = self
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        configureDataSource()
    }

    private func configureDataSource() {
        dataSource = UITableViewDiffableDataSource<FeedSection, FeedItem>(tableView: tableView) { [weak self] tableView, indexPath, item in
            guard let self else { return UITableViewCell() }
            switch item {
            case .review(let id):
                let cell = tableView.dequeueReusableCell(withIdentifier: PastFirstRowCell.identifier, for: indexPath) as! PastFirstRowCell
                if let candidate = self.pendingReviewItems.first(where: { $0.id == id }) {
                    let icon = UIImage(systemName: "mappin.and.ellipse", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
                    cell.configure(icon: icon, title: candidate.label, subtitle: candidate.date)
                }
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
            case .footer:
                let cell = tableView.dequeueReusableCell(withIdentifier: HomeStatsFooterCell.identifier, for: indexPath) as! HomeStatsFooterCell
                cell.configure(total: self.footerTotal, thisYear: self.footerThisYear, cities: self.footerCities, year: Calendar.current.component(.year, from: Date()))
                cell.onCollectionTapped = { print("Collection tapped") }
                return cell
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
        addButtonContainer.layer.cornerRadius = 14
        addButtonContainer.layer.shadowColor = UIColor.black.cgColor
        addButtonContainer.layer.shadowOpacity = 0.18
        addButtonContainer.layer.shadowOffset = CGSize(width: 0, height: 4)
        addButtonContainer.layer.shadowRadius = 10
        addButtonContainer.layer.shadowPath = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 44, height: 44), cornerRadius: 14).cgPath
        view.addSubview(addButtonContainer)

        // Orange-tinted Liquid Glass square
        let glassEffect = UIGlassEffect(style: .regular)
        glassEffect.tintColor = UIColor(named: "ClayAccent")
        let addGlass = UIVisualEffectView(effect: glassEffect)
        addGlass.translatesAutoresizingMaskIntoConstraints = false
        addGlass.layer.cornerRadius = 14
        addGlass.layer.masksToBounds = true
        addButtonContainer.addSubview(addGlass)

        addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        let plusImage = UIImage(named: "icon-plus") ?? UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .medium))
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
            addButtonContainer.widthAnchor.constraint(equalToConstant: 44),
            addButtonContainer.heightAnchor.constraint(equalToConstant: 44),

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

        mapView.alpha                    = tab == .map ? 1.0 : 0.001
        mapView.isUserInteractionEnabled = tab == .map
        mapTitleLabel.isHidden     = tab != .map
        mapInfoCard.isHidden       = tab != .map
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
        if tab == .stats {
            statsVC.refresh()
        }
        if tab == .map {
            refreshCoarseFirstAnnotations()
            updateMapInfoCard()
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

    // "N years ago today" for a same-day anniversary place, else the plain "most recent" label.
    private func heroBadgeText(for place: PlaceSummary, isAnniversary: Bool) -> String {
        guard isAnniversary else { return "Most recent first" }
        let years = Calendar.current.dateComponents([.year], from: place.firstVisitDate, to: Date()).year ?? 0
        return "\(years) year\(years == 1 ? "" : "s") ago today"
    }

    private func makeHeaderView(_ text: String, badgeCount: Int? = nil) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        guard let badgeCount else {
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

        label.text = text
        label.font = UIFont.frauncesBoldItalic(size: 21)
        label.textColor = UIColor(named: "FogBackground")
        container.addSubview(label)

        let badge = UIView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.backgroundColor = UIColor(named: "ClayAccent")
        badge.layer.cornerRadius = 14
        container.addSubview(badge)

        let badgeLabel = UILabel()
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "\(badgeCount)"
        badgeLabel.font = UIFont.karla(.bold, size: 14)
        badgeLabel.textColor = .white
        badgeLabel.textAlignment = .center
        badge.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6),
            label.trailingAnchor.constraint(lessThanOrEqualTo: badge.leadingAnchor, constant: -10),

            badge.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            badge.centerYAnchor.constraint(equalTo: label.centerYAnchor),
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28),

            badgeLabel.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
        return container
    }

    // MARK: - Home feed

    private func applySnapshot(animatingDifferences: Bool = true) {
        let places = environment.store.places
        let pending = environment.store.pendingReview
        let calendar = Calendar.current

        pendingReviewItems = pending.map { candidate in
            ReviewItem(
                id: candidate.id,
                label: candidate.placeName,
                date: reviewDateFormatter.string(from: candidate.firstVisitDate),
                reason: "\(candidate.totalPhotoCount) photo\(candidate.totalPhotoCount == 1 ? "" : "s")",
                photoLocalIDs: candidate.photoLocalIDs
            )
        }

        let currentYear = calendar.component(.year, from: Date())
        footerTotal = places.count
        footerThisYear = places.filter { calendar.component(.year, from: $0.firstVisitDate) == currentYear }.count
        footerCities = Set(places.compactMap { environment.store.place(for: $0.id)?.city }).count

        var snapshot = NSDiffableDataSourceSnapshot<FeedSection, FeedItem>()
        if !pending.isEmpty {
            snapshot.appendSections([.review])
            snapshot.appendItems(pendingReviewItems.map { .review($0.id) }, toSection: .review)
        }

        viewModelsByID.removeAll()
        placesByID.removeAll()
        mostRecentID = nil

        if !places.isEmpty {
            // Most recent first up top as the hero card — unless a past first happened on this same
            // calendar day in an earlier year, in which case that anniversary takes the hero spot.
            let sortedPlaces = places.sorted { $0.firstVisitDate > $1.firstVisitDate }
            let today = Date()
            let anniversaryPlace = sortedPlaces.first { place in
                !calendar.isDate(place.firstVisitDate, inSameDayAs: today) &&
                calendar.component(.month, from: place.firstVisitDate) == calendar.component(.month, from: today) &&
                calendar.component(.day, from: place.firstVisitDate) == calendar.component(.day, from: today)
            }
            let heroPlace = anniversaryPlace ?? sortedPlaces[0]

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
                    photoLocalIDs:   summary.photoLocalIDs,
                    badgeText:       summary.id == heroPlace.id ? heroBadgeText(for: heroPlace, isAnniversary: anniversaryPlace != nil) : "Most recent first"
                )
            }

            mostRecentID = heroPlace.id
            snapshot.appendSections([.mostRecent])
            snapshot.appendItems([.first(heroPlace.id)], toSection: .mostRecent)

            let pastPlaces = sortedPlaces.filter { $0.id != heroPlace.id }
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
        }

        snapshot.appendSections([.footer])
        snapshot.appendItems([.footer], toSection: .footer)

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

extension ViewController {
    fileprivate func presentReviewSheet(for stayID: PersistentIdentifier) {
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
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard !(annotation is MKUserLocation) else { return nil }
        let identifier = "firstPin"
        let pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        pinView.annotation = annotation
        pinView.markerTintColor = UIColor(named: "DeepPineInk")
        pinView.glyphTintColor = UIColor(named: "FogBackground")
        pinView.canShowCallout = true
        return pinView
    }
}

extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let dataSource, section < dataSource.snapshot().sectionIdentifiers.count else { return nil }
        switch dataSource.snapshot().sectionIdentifiers[section] {
        case .review:      return makeHeaderView("New firsts to review", badgeCount: pendingReviewItems.count)
        case .mostRecent:  return nil
        case .month(let date): return makeHeaderView(monthHeaderFormatter.string(from: date).uppercased())
        case .footer:      return nil
        }
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard let dataSource, section < dataSource.snapshot().sectionIdentifiers.count else { return 0 }
        switch dataSource.snapshot().sectionIdentifiers[section] {
        case .review: return 48
        case .mostRecent, .footer: return 0
        case .month: return 36
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .review(let id):
            presentReviewSheet(for: id)
        case .first(let id):
            presentPlaceDetail(for: id)
        case .footer:
            return
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
