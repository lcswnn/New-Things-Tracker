import UIKit
import MapKit
import CoreLocation

class DiscoverViewController: UIViewController {

    private var titleLabel: UILabel!
    private var subtitleLabel: UILabel!
    private var taglineLabel: UILabel!
    private var mainScrollView: UIScrollView!
    private var contentView: UIView!
    private var resultsStack: UIStackView!
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
    private var selectedCategoryGroup: NearYouCategoryGroup = .all
    private var hasLoadedNearbyFirsts = false
    private var isLoadingNearbyFirsts = false

    private static let batchSize = 10

    // Chips shown on the Discover screen — a curated subset of NearYouCategoryGroup.
    private static let displayedGroups: [NearYouCategoryGroup] = [.all, .foodAndDrink, .outdoors, .artsAndCulture]

    // Chip groups the user can filter results by, mapped onto MapKit's POI categories.
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

    private let rowColors: [UIColor] = [
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
        setupCategoryChips()
        setupResultsList()
    }

    // MARK: - Layout shell

    private func setupScrollLayout() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        view.addSubview(scrollView)
        mainScrollView = scrollView

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

    // MARK: - Title + tagline

    private func setupTitle() {
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Discover"
        titleLabel.font = UIFont.frauncesBoldItalic(size: 30)
        titleLabel.textColor = UIColor(named: "FogBackground")
        contentView.addSubview(titleLabel)

        subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "New to you, near you"
        subtitleLabel.font = UIFont.karla(.regular, size: 15)
        subtitleLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.70)
        contentView.addSubview(subtitleLabel)

        taglineLabel = UILabel()
        taglineLabel.translatesAutoresizingMaskIntoConstraints = false
        taglineLabel.text = "firsts waiting to happen"
        taglineLabel.font = UIFont.frauncesItalic(size: 17)
        taglineLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.85)
        contentView.addSubview(taglineLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            taglineLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 2),
            taglineLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
        ])
    }

    // MARK: - Category chips

    private func setupCategoryChips() {
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

        for group in Self.displayedGroups {
            let chip = makeCategoryChip(title: group.rawValue)
            chipsStack.addArrangedSubview(chip)
            categoryChips.append(chip)
        }
        for (index, chip) in categoryChips.enumerated() {
            styleChip(chip, selected: index == 0)
        }

        NSLayoutConstraint.activate([
            chipsScrollView.topAnchor.constraint(equalTo: taglineLabel.bottomAnchor, constant: 22),
            chipsScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            chipsScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            chipsScrollView.heightAnchor.constraint(equalToConstant: 40),

            chipsStack.topAnchor.constraint(equalTo: chipsScrollView.topAnchor),
            chipsStack.bottomAnchor.constraint(equalTo: chipsScrollView.bottomAnchor),
            chipsStack.leadingAnchor.constraint(equalTo: chipsScrollView.leadingAnchor, constant: 20),
            chipsStack.trailingAnchor.constraint(equalTo: chipsScrollView.trailingAnchor, constant: -20),
            chipsStack.heightAnchor.constraint(equalTo: chipsScrollView.heightAnchor),
        ])

        // Anchor the results list below the chips row
        chipsScrollView.tag = 100
    }

    private func makeCategoryChip(title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.karla(.semibold, size: 14)
            return outgoing
        }
        let button = UIButton(configuration: config)
        // The pill shape lives on the button's own layer rather than config.background — the
        // configuration-driven background view doesn't reliably render until the configuration is
        // reapplied after layout, which is why the pill was only appearing after a tap.
        button.layer.cornerRadius = 18
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
            : UIColor(named: "FogBackground")?.withAlphaComponent(0.85)
    }

    @objc private func categoryChipTapped(_ sender: UIButton) {
        guard let index = categoryChips.firstIndex(of: sender) else { return }
        let group = Self.displayedGroups[index]
        guard group != selectedCategoryGroup else { return }
        selectedCategoryGroup = group
        for (i, chip) in categoryChips.enumerated() {
            styleChip(chip, selected: i == index)
        }
        applyCategoryFilterAndDisplay()
    }

    // MARK: - Results list

    private func setupResultsList() {
        guard let chipsScroll = contentView.viewWithTag(100) else { return }

        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = UIFont.karla(.regular, size: 14)
        statusLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.55)
        statusLabel.numberOfLines = 0
        statusLabel.text = "Finding nearby firsts…"
        contentView.addSubview(statusLabel)
        nearYouStatusLabel = statusLabel

        resultsStack = UIStackView()
        resultsStack.translatesAutoresizingMaskIntoConstraints = false
        resultsStack.axis = .vertical
        resultsStack.spacing = 14
        contentView.addSubview(resultsStack)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: chipsScroll.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            resultsStack.topAnchor.constraint(equalTo: chipsScroll.bottomAnchor, constant: 24),
            resultsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            resultsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            resultsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
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

    private func showNearYouMessage(_ text: String) {
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        nearbyMapItems = []
        displayedResults = []
        displayedCount = 0
        nearYouStatusLabel.text = text
        nearYouStatusLabel.isHidden = false
    }

    // Starts a fresh "endless" browsing session over `results`: rows are revealed in small batches
    // as the user scrolls rather than all at once, so it feels like a continuous stream of places.
    private func beginDisplayingResults(_ results: [(item: MKMapItem, distance: CLLocationDistance)]) {
        nearYouStatusLabel.isHidden = true
        resultsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        displayedResults = results
        displayedCount = 0
        nearbyMapItems = []

        appendNextBatch()
    }

    private func appendNextBatch() {
        guard displayedCount < displayedResults.count else { return }
        let end = min(displayedCount + Self.batchSize, displayedResults.count)
        let batch = displayedResults[displayedCount..<end]

        for result in batch {
            let index = nearbyMapItems.count
            nearbyMapItems.append(result.item)

            let color = rowColors[index % rowColors.count]
            let distanceText = distanceFormatter.string(fromDistance: result.distance)
            let row = makeDiscoverRow(
                title: result.item.name ?? "Somewhere new",
                category: groupLabel(for: result.item.pointOfInterestCategory),
                distance: distanceText,
                color: color,
                icon: iconName(for: result.item.pointOfInterestCategory)
            )
            row.tag = index
            row.isUserInteractionEnabled = true
            row.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(discoverRowTapped(_:))))
            resultsStack.addArrangedSubview(row)
        }

        displayedCount = end
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

    // Human-readable category name for the row subtitle — the group that owns this POI category,
    // falling back to "Nearby" for anything outside the curated chip groups (e.g. Fun & Nightlife).
    private func groupLabel(for category: MKPointOfInterestCategory?) -> String {
        guard let category else { return "Nearby" }
        for group in NearYouCategoryGroup.allCases where group != .all {
            if group.categories?.contains(category) == true { return group.rawValue }
        }
        return "Nearby"
    }

    @objc private func discoverRowTapped(_ gesture: UITapGestureRecognizer) {
        guard let tag = gesture.view?.tag, tag < nearbyMapItems.count else { return }
        let detailVC = MKMapItemDetailViewController(mapItem: nearbyMapItems[tag])
        detailVC.delegate = self
        present(detailVC, animated: true)
    }

    // MARK: - Row builder

    private func makeDiscoverRow(title: String, category: String, distance: String, color: UIColor, icon: String) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8

        let thumb = UIView()
        thumb.translatesAutoresizingMaskIntoConstraints = false
        thumb.backgroundColor = color
        thumb.layer.cornerRadius = 16
        thumb.clipsToBounds = true
        card.addSubview(thumb)

        let iconView = UIImageView(image: UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .medium)))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .center
        iconView.tintColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.55)
        thumb.addSubview(iconView)

        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor(named: "ClayAccent")
        pill.layer.cornerRadius = 13
        card.addSubview(pill)

        let pillLabel = UILabel()
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.text = "Not yet visited"
        pillLabel.font = UIFont.karla(.semibold, size: 12)
        pillLabel.textColor = UIColor(named: "FogBackground")
        pill.addSubview(pillLabel)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.fraunces(.bold, size: 19)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 2
        card.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "\(category) · \(distance)"
        subtitleLabel.font = UIFont.karla(.regular, size: 13)
        subtitleLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50)
        card.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            thumb.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            thumb.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            thumb.widthAnchor.constraint(equalToConstant: 88),
            thumb.heightAnchor.constraint(equalToConstant: 88),

            iconView.centerXAnchor.constraint(equalTo: thumb.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: thumb.centerYAnchor),

            pill.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            pill.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            pillLabel.topAnchor.constraint(equalTo: pill.topAnchor, constant: 6),
            pillLabel.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -6),
            pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),

            titleLabel.leadingAnchor.constraint(equalTo: thumb.trailingAnchor, constant: 14),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pill.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            card.bottomAnchor.constraint(greaterThanOrEqualTo: thumb.bottomAnchor, constant: 16),
            card.bottomAnchor.constraint(greaterThanOrEqualTo: subtitleLabel.bottomAnchor, constant: 16),
        ])

        return card
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
    // Reveals the next batch of results as the user approaches the bottom of the page, so the
    // list keeps feeding fresh places instead of stopping at a hard cutoff.
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === mainScrollView else { return }
        let threshold: CGFloat = 500
        if scrollView.contentOffset.y + scrollView.bounds.height > scrollView.contentSize.height - threshold {
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
