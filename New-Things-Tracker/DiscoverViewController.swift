import UIKit
import MapKit
import CoreLocation

class DiscoverViewController: UIViewController {

    private var titleLabel: UILabel!
    private var contextLabel: UILabel!
    private var searchContainer: UIView!
    private var contentView: UIView!
    private var trendingStack: UIStackView!
    private var nearYouScrollView: UIScrollView!
    private var nearYouStatusLabel: UILabel!
    private var categoryChips: [UIButton] = []

    // MARK: - Nearby-firsts data pipeline
    private let locationManager = CLLocationManager()
    private let distanceFormatter = MKDistanceFormatter()
    private var activeSearches: [MKLocalSearch] = []
    private var visitedCoordinates: [CLLocationCoordinate2D] = []
    private var nearbyMapItems: [MKMapItem] = []
    private var allRankedResults: [(item: MKMapItem, distance: CLLocationDistance)] = []
    private var displayedResults: [(item: MKMapItem, distance: CLLocationDistance)] = []
    private var displayedCount = 0
    private var nearYouCardRightEdge: CGFloat = DiscoverViewController.cardLeadingInset
    private var selectedCategoryGroup: NearYouCategoryGroup = .all
    private var hasLoadedNearbyFirsts = false
    private var isLoadingNearbyFirsts = false

    private static let cardWidth: CGFloat = 160
    private static let cardHeight: CGFloat = 190
    private static let cardGap: CGFloat = 12
    private static let cardLeadingInset: CGFloat = 20
    private static let batchSize = 8

    // Chip groups the user can filter "Near You" results by, mapped onto MapKit's POI categories.
    private enum NearYouCategoryGroup: String, CaseIterable {
        case all = "All"
        case foodAndDrink = "Food & Drink"
        case outdoors = "Outdoors"
        case artsAndCulture = "Arts & Culture"
        case funAndNightlife = "Fun & Nightlife"

        // nil means "no filter" — include every category in experienceCategories.
        var categories: [MKPointOfInterestCategory]? {
            switch self {
            case .all:
                return nil
            case .foodAndDrink:
                return [.restaurant, .cafe, .bakery, .brewery, .winery, .distillery]
            case .outdoors:
                return [.park, .nationalPark, .beach, .campground, .marina, .hiking,
                        .kayaking, .surfing, .swimming, .fishing, .golf, .miniGolf, .skiing]
            case .artsAndCulture:
                return [.museum, .musicVenue, .theater, .landmark, .nationalMonument, .castle, .fortress]
            case .funAndNightlife:
                return [.amusementPark, .aquarium, .zoo, .fairground, .movieTheater,
                        .nightlife, .bowling, .goKart, .rockClimbing, .skating, .stadium]
            }
        }
    }

    // Curated set of "things to experience" — excludes utility categories like gas stations, ATMs, banks.
    private static let experienceCategories: [MKPointOfInterestCategory] = [
        .restaurant, .cafe, .bakery, .brewery, .winery, .distillery,
        .museum, .musicVenue, .theater, .movieTheater, .nightlife,
        .park, .nationalPark, .beach, .campground, .marina, .zoo, .aquarium,
        .amusementPark, .fairground, .landmark, .nationalMonument, .castle, .fortress,
        .hiking, .golf, .miniGolf, .bowling, .goKart, .rockClimbing,
        .skiing, .skating, .kayaking, .surfing, .swimming, .fishing, .stadium,
    ]

    private let nearYouColors: [UIColor] = [
        UIColor(red: 0.79, green: 0.87, blue: 0.82, alpha: 1),
        UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1),
        UIColor(named: "ClayAccent")?.withAlphaComponent(0.5) ?? .orange,
        UIColor(named: "DustySage")?.withAlphaComponent(0.65) ?? .gray,
        UIColor(red: 0.82, green: 0.88, blue: 0.75, alpha: 1),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        locationManager.delegate = self
        setupScrollLayout()
        setupTitle()
        setupSearchBar()
        setupNearYouSection()
        setupTrendingSection()
        setupFriendsSection()
    }

    // MARK: - Layout shell

    private func setupScrollLayout() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
        ])
    }

    // MARK: - Title + context

    private func setupTitle() {
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Discover"
        titleLabel.font = UIFont.fraunces(.bold, size: 26)
        titleLabel.textColor = UIColor(named: "FogBackground")
        contentView.addSubview(titleLabel)

        contextLabel = UILabel()
        contextLabel.translatesAutoresizingMaskIntoConstraints = false
        contextLabel.text = "Finding your location…"
        contextLabel.font = UIFont.karla(.regular, size: 14)
        contextLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.65)
        contentView.addSubview(contextLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            contextLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            contextLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
        ])
    }

    // MARK: - Search bar

    private func setupSearchBar() {
        searchContainer = UIView()
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.12)
        searchContainer.layer.cornerRadius = 14
        contentView.addSubview(searchContainer)

        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        searchIcon.tintColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.45)
        searchIcon.contentMode = .scaleAspectFit
        searchContainer.addSubview(searchIcon)

        let searchField = UITextField()
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.font = UIFont.karla(.regular, size: 15)
        searchField.textColor = UIColor(named: "FogBackground")
        searchField.tintColor = UIColor(named: "FogBackground")
        searchField.attributedPlaceholder = NSAttributedString(
            string: "Search places, experiences...",
            attributes: [
                .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.38) ?? UIColor.gray,
                .font: UIFont.karla(.regular, size: 15)
            ]
        )
        searchContainer.addSubview(searchField)

        NSLayoutConstraint.activate([
            searchContainer.topAnchor.constraint(equalTo: contextLabel.bottomAnchor, constant: 18),
            searchContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            searchContainer.heightAnchor.constraint(equalToConstant: 46),

            searchIcon.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 14),
            searchIcon.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 17),
            searchIcon.heightAnchor.constraint(equalToConstant: 17),

            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 9),
            searchField.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -14),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
        ])
    }

    // MARK: - Near You

    private func setupNearYouSection() {
        let sectionLabel = makeSectionHeader("Near You")
        contentView.addSubview(sectionLabel)

        let chipsScrollView = UIScrollView()
        chipsScrollView.translatesAutoresizingMaskIntoConstraints = false
        chipsScrollView.showsHorizontalScrollIndicator = false
        chipsScrollView.alwaysBounceHorizontal = true
        contentView.addSubview(chipsScrollView)

        let chipsStack = UIStackView()
        chipsStack.translatesAutoresizingMaskIntoConstraints = false
        chipsStack.axis = .horizontal
        chipsStack.spacing = 8
        chipsScrollView.addSubview(chipsStack)

        for group in NearYouCategoryGroup.allCases {
            let chip = makeCategoryChip(title: group.rawValue)
            chipsStack.addArrangedSubview(chip)
            categoryChips.append(chip)
        }
        for (index, chip) in categoryChips.enumerated() {
            styleChip(chip, selected: index == 0)
        }

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        scrollView.delegate = self
        contentView.addSubview(scrollView)
        nearYouScrollView = scrollView

        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.karla(.regular, size: 14)
        statusLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.5)
        statusLabel.numberOfLines = 0
        statusLabel.text = "Finding nearby firsts…"
        contentView.addSubview(statusLabel)
        nearYouStatusLabel = statusLabel

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 30),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            chipsScrollView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 12),
            chipsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chipsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chipsScrollView.heightAnchor.constraint(equalToConstant: 34),

            chipsStack.topAnchor.constraint(equalTo: chipsScrollView.topAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScrollView.bottomAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScrollView.leadingAnchor, constant: 20),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScrollView.trailingAnchor, constant: -20),
            chipsStack.heightAnchor.constraint(equalTo: chipsScrollView.heightAnchor),

            scrollView.topAnchor.constraint(equalTo: chipsScrollView.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 200),

            statusLabel.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
        ])

        // Keep a reference so Trending can anchor below
        scrollView.tag = 100
    }

    private func makeCategoryChip(title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.karla(.semibold, size: 13)
            return outgoing
        }
        let button = UIButton(configuration: config)
        // The pill shape lives on the button's own layer rather than config.background — the
        // configuration-driven background view doesn't reliably render until the configuration is
        // reapplied after layout, which is why the pill was only appearing after a tap.
        button.layer.cornerRadius = 16
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(categoryChipTapped(_:)), for: .touchUpInside)
        return button
    }

    private func styleChip(_ chip: UIButton, selected: Bool) {
        guard var config = chip.configuration else { return }
        config.baseForegroundColor = selected ? UIColor(named: "FogBackground") : UIColor(named: "DeepPineInk")
        chip.configuration = config
        chip.backgroundColor = selected
            ? UIColor(named: "ClayAccent")
            : UIColor(named: "FogBackground")?.withAlphaComponent(0.7)
    }

    @objc private func categoryChipTapped(_ sender: UIButton) {
        guard let index = categoryChips.firstIndex(of: sender) else { return }
        let group = NearYouCategoryGroup.allCases[index]
        guard group != selectedCategoryGroup else { return }
        selectedCategoryGroup = group
        for (i, chip) in categoryChips.enumerated() {
            styleChip(chip, selected: i == index)
        }
        applyCategoryFilterAndDisplay()
    }

    // MARK: - Nearby-firsts pipeline (public API for the parent view controller)

    // Snapshot of the places the user has already visited, so real POI results can exclude them.
    func updateVisitedCoordinates(_ coordinates: [CLLocationCoordinate2D]) {
        visitedCoordinates = coordinates
    }

    // Called by the parent view controller when this tab becomes active. Loads once per session;
    // permission-denied/error states are allowed to retry on the next visit since MapKit's on-device
    // search is free and there's no cost to trying again.
    func refreshIfNeeded() {
        guard !hasLoadedNearbyFirsts, !isLoadingNearbyFirsts else { return }
        beginLocationLookup()
    }

    private func beginLocationLookup() {
        isLoadingNearbyFirsts = true
        selectedCategoryGroup = .all
        for (index, chip) in categoryChips.enumerated() {
            styleChip(chip, selected: index == 0)
        }
        showNearYouMessage("Finding nearby firsts…")

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            isLoadingNearbyFirsts = false
            showNearYouMessage("Enable Location Services in Settings to see nearby firsts.")
        @unknown default:
            isLoadingNearbyFirsts = false
        }
    }

    // MKLocalPointsOfInterestRequest silently clamps each request to MKLocalPointsOfInterestRequest.maxRadius
    // (~2km), so a wider "increase the radius" effect is built from a grid of overlapping requests around
    // the user rather than one large radius, which MapKit would just clamp back down anyway.
    private func searchNearbyFirsts(around coordinate: CLLocationCoordinate2D) {
        cancelPendingSearches()

        let maxRadius = MKLocalPointsOfInterestRequest.maxRadius
        let centers = searchGridCenters(around: coordinate)
        var collected: [String: MKMapItem] = [:]
        let group = DispatchGroup()

        for center in centers {
            let request = MKLocalPointsOfInterestRequest(center: center, radius: maxRadius)
            request.pointOfInterestFilter = MKPointOfInterestFilter(including: Self.experienceCategories)

            let search = MKLocalSearch(request: request)
            activeSearches.append(search)
            group.enter()
            search.start { [weak self] response, _ in
                DispatchQueue.main.async {
                    if let self, let items = response?.mapItems {
                        for item in items {
                            collected[self.dedupeKey(for: item)] = item
                        }
                    }
                    group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.handleSearchResults(Array(collected.values), origin: coordinate)
        }
    }

    // A ring of overlapping ~2km-radius requests around the user, extending coverage out to roughly
    // 9km without exceeding MapKit's per-request cap — meaningfully bigger in cities and suburbs alike.
    private func searchGridCenters(around origin: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let innerRingBearings: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
        let outerRingBearings: [Double] = [0, 90, 180, 270]

        var centers = [origin]
        centers += innerRingBearings.map { offsetCoordinate(from: origin, distanceMeters: 3_500, bearingDegrees: $0) }
        centers += outerRingBearings.map { offsetCoordinate(from: origin, distanceMeters: 7_000, bearingDegrees: $0) }
        return centers
    }

    private func offsetCoordinate(from origin: CLLocationCoordinate2D, distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let bearing = bearingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearing))
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    // The same real-world place can come back from several overlapping grid requests; this key
    // collapses those duplicates before ranking.
    private func dedupeKey(for item: MKMapItem) -> String {
        let lat = (item.placemark.coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (item.placemark.coordinate.longitude * 10_000).rounded() / 10_000
        return "\(item.name ?? "")|\(lat)|\(lon)"
    }

    private func cancelPendingSearches() {
        activeSearches.forEach { $0.cancel() }
        activeSearches.removeAll()
    }

    private func handleSearchResults(_ mapItems: [MKMapItem], origin: CLLocationCoordinate2D) {
        isLoadingNearbyFirsts = false
        hasLoadedNearbyFirsts = true

        guard !mapItems.isEmpty else {
            allRankedResults = []
            showNearYouMessage("No new places to discover nearby yet.")
            updateContextLabel(origin: origin, count: 0)
            return
        }

        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let visitedLocations = visitedCoordinates.map {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude)
        }

        allRankedResults = mapItems
            .filter { item in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                return !visitedLocations.contains { $0.distance(from: itemLocation) < 120 }
            }
            .map { item -> (item: MKMapItem, distance: CLLocationDistance) in
                let itemLocation = CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
                return (item, originLocation.distance(from: itemLocation))
            }
            .sorted { $0.distance < $1.distance }

        updateContextLabel(origin: origin, count: allRankedResults.count)
        applyCategoryFilterAndDisplay()
    }

    // Re-filters the already-fetched results by the selected chip — no new network/search call needed.
    private func applyCategoryFilterAndDisplay() {
        let filtered: [(item: MKMapItem, distance: CLLocationDistance)]
        if let categories = selectedCategoryGroup.categories {
            filtered = allRankedResults.filter { result in
                guard let category = result.item.pointOfInterestCategory else { return false }
                return categories.contains(category)
            }
        } else {
            filtered = allRankedResults
        }

        guard !filtered.isEmpty else {
            showNearYouMessage(selectedCategoryGroup == .all
                ? "Looks like you've already tried everything nearby!"
                : "No \(selectedCategoryGroup.rawValue.lowercased()) nearby yet.")
            return
        }

        beginDisplayingResults(filtered)
    }

    private func updateContextLabel(origin: CLLocationCoordinate2D, count: Int) {
        let location = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let place = placemarks?.first
            let locationText = [place?.locality ?? place?.subAdministrativeArea, place?.administrativeArea]
                .compactMap { $0 }
                .joined(separator: ", ")

            DispatchQueue.main.async {
                let countText = "\(count) new thing\(count == 1 ? "" : "s") to try nearby"
                self.contextLabel.text = locationText.isEmpty ? countText : "\(locationText)  ·  \(countText)"
            }
        }
    }

    private func showNearYouMessage(_ text: String) {
        nearYouScrollView.subviews.forEach { $0.removeFromSuperview() }
        nearbyMapItems = []
        displayedResults = []
        displayedCount = 0
        nearYouStatusLabel.text = text
        nearYouStatusLabel.isHidden = false
    }

    // Starts a fresh "endless" browsing session over `results`: cards are revealed in small batches
    // as the user scrolls rather than all at once, so it feels like a continuous stream of places.
    private func beginDisplayingResults(_ results: [(item: MKMapItem, distance: CLLocationDistance)]) {
        nearYouStatusLabel.isHidden = true
        nearYouScrollView.subviews.forEach { $0.removeFromSuperview() }

        displayedResults = results
        displayedCount = 0
        nearbyMapItems = []
        nearYouCardRightEdge = Self.cardLeadingInset
        nearYouScrollView.contentSize = CGSize(width: 0, height: Self.cardHeight)

        appendNextBatch()
    }

    private func appendNextBatch() {
        guard displayedCount < displayedResults.count else { return }
        let end = min(displayedCount + Self.batchSize, displayedResults.count)
        let batch = displayedResults[displayedCount..<end]

        for result in batch {
            let index = nearbyMapItems.count
            nearbyMapItems.append(result.item)

            let color = nearYouColors[index % nearYouColors.count]
            let distanceText = distanceFormatter.string(fromDistance: result.distance) + " away"
            let card = makeNearYouCard(
                title: result.item.name ?? "Somewhere new", distance: distanceText, color: color,
                icon: iconName(for: result.item.pointOfInterestCategory),
                width: Self.cardWidth, height: Self.cardHeight
            )
            card.frame = CGRect(x: nearYouCardRightEdge, y: 0, width: Self.cardWidth, height: Self.cardHeight)
            card.tag = index
            card.isUserInteractionEnabled = true
            card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(nearYouCardTapped(_:))))
            nearYouScrollView.addSubview(card)
            nearYouCardRightEdge += Self.cardWidth + Self.cardGap
        }

        displayedCount = end
        nearYouScrollView.contentSize = CGSize(width: nearYouCardRightEdge - Self.cardGap + Self.cardLeadingInset, height: Self.cardHeight)
    }

    // A category-matched SF Symbol instead of a photo — no risk of showing the wrong building/business
    // (which street-level imagery sometimes does), no per-place network fetch, and no async pop-in.
    private func iconName(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "mappin.and.ellipse" }
        switch category {
        case .restaurant: return "fork.knife"
        case .cafe: return "cup.and.saucer.fill"
        case .bakery: return "birthday.cake.fill"
        case .brewery: return "mug.fill"
        case .winery: return "wineglass.fill"
        case .distillery: return "flame.fill"
        case .museum: return "building.columns.fill"
        case .musicVenue: return "music.note"
        case .theater: return "theatermasks.fill"
        case .movieTheater: return "film.fill"
        case .nightlife: return "moon.stars.fill"
        case .park: return "tree.fill"
        case .nationalPark: return "mountain.2.fill"
        case .beach: return "beach.umbrella.fill"
        case .campground: return "tent.fill"
        case .marina: return "sailboat.fill"
        case .zoo: return "pawprint.fill"
        case .aquarium: return "fish.fill"
        case .amusementPark: return "ferriswheel"
        case .fairground: return "balloon.2.fill"
        case .landmark: return "building.2.fill"
        case .nationalMonument: return "flag.fill"
        case .castle: return "crown.fill"
        case .fortress: return "shield.fill"
        case .hiking: return "figure.hiking"
        case .golf, .miniGolf: return "figure.golf"
        case .bowling: return "circle.grid.3x3.fill"
        case .goKart: return "car.fill"
        case .rockClimbing: return "figure.climbing"
        case .skiing: return "figure.skiing.downhill"
        case .skating: return "figure.skating"
        case .swimming: return "figure.pool.swim"
        case .kayaking, .surfing: return "water.waves"
        case .fishing: return "fish.fill"
        case .stadium: return "sportscourt.fill"
        default: return "mappin.and.ellipse"
        }
    }

    @objc private func nearYouCardTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag, tag < nearbyMapItems.count else { return }
        let detailVC = MKMapItemDetailViewController(mapItem: nearbyMapItems[tag])
        detailVC.delegate = self
        present(detailVC, animated: true)
    }

    // MARK: - Trending

    private func setupTrendingSection() {
        guard let nearYouScroll = contentView.viewWithTag(100) else { return }

        let sectionLabel = makeSectionHeader("Trending in Chicago")
        contentView.addSubview(sectionLabel)

        let trending: [(rank: Int, title: String, category: String, count: String)] = [
            (1, "Kayaking on Lake Michigan",    "Adventure", "234 people this week"),
            (2, "Architecture Boat Tour",       "Culture",   "189 people this week"),
            (3, "Deep Dish Pizza Making Class", "Food",      "156 people this week"),
        ]

        trendingStack = UIStackView()
        trendingStack.translatesAutoresizingMaskIntoConstraints = false
        trendingStack.axis = .vertical
        trendingStack.spacing = 10
        contentView.addSubview(trendingStack)

        for item in trending {
            trendingStack.addArrangedSubview(makeTrendingRow(rank: item.rank, title: item.title, category: item.category, count: item.count))
        }

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: nearYouScroll.bottomAnchor, constant: 34),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            trendingStack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14),
            trendingStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            trendingStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Helpers

    private func makeSectionHeader(_ text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.font = UIFont.fraunces(.bold, size: 20)
        label.textColor = UIColor(named: "FogBackground")
        return label
    }

    private func makeNearYouCard(title: String, distance: String, color: UIColor, icon: String, width: CGFloat, height: CGFloat) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8

        let photoH = height * 0.58
        let photoView = UIView()
        photoView.backgroundColor = color
        photoView.frame = CGRect(x: 0, y: 0, width: width, height: photoH)
        photoView.layer.cornerRadius = 18
        photoView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        photoView.clipsToBounds = true
        card.addSubview(photoView)

        // A category icon instead of a photo — set once, synchronously, no network fetch involved.
        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)))
        iconView.frame = photoView.bounds
        iconView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        iconView.contentMode = .center
        iconView.tintColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.55)
        photoView.addSubview(iconView)

        let labelY = photoH + 10
        let titleLabel = UILabel()
        titleLabel.font = UIFont.fraunces(.bold, size: 14)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.text = title
        titleLabel.numberOfLines = 2
        titleLabel.frame = CGRect(x: 12, y: labelY, width: width - 24, height: 38)
        card.addSubview(titleLabel)

        let distLabel = UILabel()
        distLabel.font = UIFont.karla(.regular, size: 11)
        distLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.45)
        distLabel.text = distance
        distLabel.frame = CGRect(x: 12, y: labelY + 40, width: width - 24, height: 16)
        card.addSubview(distLabel)

        return card
    }

    private func makeTrendingRow(rank: Int, title: String, category: String, count: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6

        // Rank number
        let rankLabel = UILabel()
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        rankLabel.text = "\(rank)"
        rankLabel.font = UIFont.fraunces(.bold, size: 22)
        rankLabel.textColor = rank <= 3
            ? UIColor(named: "ClayAccent")
            : UIColor(named: "DeepPineInk")?.withAlphaComponent(0.25)
        rankLabel.textAlignment = .center
        rankLabel.setContentHuggingPriority(.required, for: .horizontal)
        card.addSubview(rankLabel)

        // Text stack
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.fraunces(.bold, size: 15)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 2

        let countLabel = UILabel()
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.text = count
        countLabel.font = UIFont.karla(.regular, size: 12)
        countLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.45)

        let textStack = UIStackView(arrangedSubviews: [titleLabel, countLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 3
        card.addSubview(textStack)

        // Category pill
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor(named: "DustySage")?.withAlphaComponent(0.45)
        pill.layer.cornerRadius = 10
        pill.setContentHuggingPriority(.required, for: .horizontal)
        card.addSubview(pill)

        let pillLabel = UILabel()
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.text = category
        pillLabel.font = UIFont.karla(.semibold, size: 11)
        pillLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.7)
        pill.addSubview(pillLabel)

        NSLayoutConstraint.activate([
            rankLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            rankLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            rankLabel.widthAnchor.constraint(equalToConstant: 28),

            textStack.leadingAnchor.constraint(equalTo: rankLabel.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            textStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: pill.leadingAnchor, constant: -10),

            // Pill: sized to its content, anchored to trailing edge only
            pill.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            pill.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 5),
            pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -5),
            pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
        ])

        card.heightAnchor.constraint(greaterThanOrEqualToConstant: 70).isActive = true
        return card
    }

    // MARK: - Friends' Firsts

    private func setupFriendsSection() {
        let sectionLabel = makeSectionHeader("Friends' Firsts")
        contentView.addSubview(sectionLabel)

        let friends: [(initials: String, name: String, activity: String, time: String, color: UIColor)] = [
            ("SM", "Sarah M.",  "hiked the lakefront trail",       "2h ago",    UIColor(red: 0.85, green: 0.73, blue: 0.70, alpha: 1)),
            ("JT", "Jake T.",   "tried Ethiopian food",            "Yesterday", UIColor(red: 0.70, green: 0.80, blue: 0.76, alpha: 1)),
            ("MR", "Maya R.",   "went to an improv show",          "3d ago",    UIColor(red: 0.79, green: 0.75, blue: 0.88, alpha: 1)),
        ]

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 10
        contentView.addSubview(stack)

        for friend in friends {
            stack.addArrangedSubview(makeFriendRow(
                initials: friend.initials,
                name: friend.name,
                activity: friend.activity,
                time: friend.time,
                avatarColor: friend.color
            ))
        }

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: trendingStack.bottomAnchor, constant: 34),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            stack.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    private func makeFriendRow(initials: String, name: String, activity: String, time: String, avatarColor: UIColor) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        // Avatar circle
        let avatar = UIView()
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.backgroundColor = avatarColor
        avatar.layer.cornerRadius = 22
        row.addSubview(avatar)

        let initialsLabel = UILabel()
        initialsLabel.translatesAutoresizingMaskIntoConstraints = false
        initialsLabel.text = initials
        initialsLabel.font = UIFont.karla(.bold, size: 13)
        initialsLabel.textColor = .white
        initialsLabel.textAlignment = .center
        avatar.addSubview(initialsLabel)

        // Name + activity text
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text = name
        nameLabel.font = UIFont.karla(.bold, size: 14)
        nameLabel.textColor = UIColor(named: "FogBackground")

        // Attributed activity string: "first time" in italic Fraunces, activity in regular
        let activityText = NSMutableAttributedString(
            string: "first time · ",
            attributes: [
                .font: UIFont.fraunces(.bold, size: 13),
                .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.55) ?? UIColor.gray
            ]
        )
        activityText.append(NSAttributedString(
            string: activity,
            attributes: [
                .font: UIFont.karla(.regular, size: 13),
                .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.80) ?? UIColor.gray
            ]
        ))
        let activityLabel = UILabel()
        activityLabel.translatesAutoresizingMaskIntoConstraints = false
        activityLabel.attributedText = activityText
        activityLabel.numberOfLines = 2

        let textStack = UIStackView(arrangedSubviews: [nameLabel, activityLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 3
        row.addSubview(textStack)

        // Time label
        let timeLabel = UILabel()
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.text = time
        timeLabel.font = UIFont.karla(.regular, size: 11)
        timeLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.40)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        row.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            avatar.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),

            initialsLabel.centerXAnchor.constraint(equalTo: avatar.centerXAnchor),
            initialsLabel.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: row.topAnchor, constant: 4),
            textStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 52),
        ])

        return row
    }
}

// MARK: - CLLocationManagerDelegate

extension DiscoverViewController: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLoadingNearbyFirsts = false
            showNearYouMessage("Enable Location Services in Settings to see nearby firsts.")
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        searchNearbyFirsts(around: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoadingNearbyFirsts = false
        showNearYouMessage("Couldn't determine your location.")
    }
}

// MARK: - UIScrollViewDelegate

extension DiscoverViewController: UIScrollViewDelegate {
    // Reveals the next batch of "Near You" cards as the user approaches the trailing edge,
    // so the row keeps feeding fresh places instead of stopping at a hard cutoff.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === nearYouScrollView else { return }
        let threshold: CGFloat = 400
        if scrollView.contentOffset.x + scrollView.bounds.width > scrollView.contentSize.width - threshold {
            appendNextBatch()
        }
    }
}

// MARK: - MKMapItemDetailViewControllerDelegate

extension DiscoverViewController: MKMapItemDetailViewControllerDelegate {
    func mapItemDetailViewControllerDidFinish(_ detailViewController: MKMapItemDetailViewController) {
        detailViewController.dismiss(animated: true)
    }
}
