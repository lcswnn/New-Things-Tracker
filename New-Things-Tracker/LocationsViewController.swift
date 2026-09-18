import UIKit
import CoreLocation
import MapKit

struct SavedLocation: Codable {
    var id: String
    var label: String
    var addressName: String?
    var latitude: Double?
    var longitude: Double?
    var isBuiltIn: Bool

    var isSet: Bool { latitude != nil }

    static func loadAll() -> [SavedLocation] {
        if let data = UserDefaults.standard.data(forKey: "savedLocations"),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            return decoded
        }
        // First launch — migrate any previously-set home coordinate
        var defaults: [SavedLocation] = [
            SavedLocation(id: "home", label: "Home", addressName: nil, latitude: nil, longitude: nil, isBuiltIn: true),
            SavedLocation(id: "work", label: "Work", addressName: nil, latitude: nil, longitude: nil, isBuiltIn: true),
        ]
        let lat = UserDefaults.standard.double(forKey: "homeLatitude")
        let lon = UserDefaults.standard.double(forKey: "homeLongitude")
        if lat != 0 || lon != 0 {
            defaults[0].latitude    = lat
            defaults[0].longitude   = lon
            defaults[0].addressName = UserDefaults.standard.string(forKey: "homeAddressName")
        }
        return defaults
    }
}

protocol LocationsViewControllerDelegate: AnyObject {
    func locationsDidUpdate()
}

class LocationsViewController: UIViewController {

    weak var delegate: LocationsViewControllerDelegate?

    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private var locationsStack: UIStackView!
    private var locations: [SavedLocation] = []
    private let locationManager = CLLocationManager()
    private var settingIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        locationManager.delegate = self
        locations = SavedLocation.loadAll()
        setupScrollLayout()
        setupContent()
    }

    // MARK: - Persistence

    private func saveLocations() {
        if let data = try? JSONEncoder().encode(locations) {
            UserDefaults.standard.set(data, forKey: "savedLocations")
        }
        // Keep legacy keys in sync so PhotoMetadataManager continues to work
        if let home = locations.first(where: { $0.id == "home" }),
           let lat = home.latitude, let lon = home.longitude {
            UserDefaults.standard.set(lat,              forKey: "homeLatitude")
            UserDefaults.standard.set(lon,              forKey: "homeLongitude")
            UserDefaults.standard.set(home.addressName, forKey: "homeAddressName")
        }
        delegate?.locationsDidUpdate()
    }

    // MARK: - Scroll layout

    private func setupScrollLayout() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .automatic
        view.addSubview(scrollView)

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

    // MARK: - Content

    private func setupContent() {
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text      = "Locations"
        titleLabel.font      = .fraunces(.bold, size: 24)
        titleLabel.textColor = UIColor(named: "FogBackground")
        contentView.addSubview(titleLabel)

        let subtitleLabel = UILabel()
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text      = "Places you regularly visit"
        subtitleLabel.font      = .karla(.regular, size: 14)
        subtitleLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.55)
        contentView.addSubview(subtitleLabel)

        locationsStack = UIStackView()
        locationsStack.translatesAutoresizingMaskIntoConstraints = false
        locationsStack.axis    = .vertical
        locationsStack.spacing = 12
        contentView.addSubview(locationsStack)

        let addButton = UIButton(type: .system)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.setTitle("+ Add Location", for: .normal)
        addButton.titleLabel?.font = .karla(.semibold, size: 15)
        addButton.tintColor = UIColor(named: "ClayAccent")
        addButton.addTarget(self, action: #selector(addLocationTapped), for: .touchUpInside)
        contentView.addSubview(addButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            locationsStack.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            locationsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            locationsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            addButton.topAnchor.constraint(equalTo: locationsStack.bottomAnchor, constant: 28),
            addButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            addButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -44),
        ])

        rebuildCards()
    }

    private func rebuildCards() {
        locationsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, loc) in locations.enumerated() {
            locationsStack.addArrangedSubview(makeCard(loc, index: i))
        }
    }

    // MARK: - Card builder

    private func makeCard(_ location: SavedLocation, index: Int) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor    = UIColor(named: "FogBackground")?.withAlphaComponent(0.10)
        card.layer.cornerRadius = 16
        card.layer.borderWidth  = 0.5
        card.layer.borderColor  = UIColor(named: "FogBackground")?.withAlphaComponent(0.20).cgColor
        card.clipsToBounds      = true   // so chin corners follow card's corner radius

        // — Icon circle —
        let iconBg = UIView()
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.backgroundColor    = UIColor(named: "ClayAccent")?.withAlphaComponent(0.65)
        iconBg.layer.cornerRadius = 22
        card.addSubview(iconBg)

        let iconName: String
        switch location.id {
        case "home": iconName = "house.fill"
        case "work": iconName = "briefcase.fill"
        default:     iconName = "mappin.fill"
        }
        let icon = UIImageView(image: UIImage(systemName: iconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor   = UIColor(named: "FogBackground")
        icon.contentMode = .scaleAspectFit
        iconBg.addSubview(icon)

        // — Labels —
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text      = location.label
        nameLabel.font      = .karla(.semibold, size: 15)
        nameLabel.textColor = UIColor(named: "FogBackground")
        card.addSubview(nameLabel)

        let addrLabel = UILabel()
        addrLabel.translatesAutoresizingMaskIntoConstraints = false
        addrLabel.text          = location.addressName ?? "Not set"
        addrLabel.font          = .karla(.regular, size: 13)
        addrLabel.textColor     = UIColor(named: "FogBackground")?.withAlphaComponent(0.50)
        addrLabel.numberOfLines = 2
        card.addSubview(addrLabel)

        // — Divider between body and chin —
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.14)
        card.addSubview(divider)

        // — Chin —
        let chin = UIView()
        chin.translatesAutoresizingMaskIntoConstraints = false
        chin.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.06)
        card.addSubview(chin)

        // — Chin button stack: equal-width pill buttons side by side —
        let chinStack = UIStackView()
        chinStack.translatesAutoresizingMaskIntoConstraints = false
        chinStack.axis         = .horizontal
        chinStack.distribution = .fillEqually
        chinStack.spacing      = 8
        chin.addSubview(chinStack)

        chinStack.addArrangedSubview(makeChinButton(
            title: location.isSet ? "Change" : "Set Location",
            foreground: UIColor(named: "ClayAccent"),
            tag: index,
            action: #selector(setTapped(_:))
        ))

        if !location.isBuiltIn {
            chinStack.addArrangedSubview(makeChinButton(
                title: "Delete",
                foreground: UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50),
                tag: index,
                action: #selector(deleteTapped(_:))
            ))
        }

        NSLayoutConstraint.activate([
            // Icon — top-aligned with body padding
            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            iconBg.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            iconBg.widthAnchor.constraint(equalToConstant: 44),
            iconBg.heightAnchor.constraint(equalToConstant: 44),
            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            // Labels
            nameLabel.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            addrLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            addrLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            addrLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            // Divider sits below whichever is taller: the icon or the address text
            divider.topAnchor.constraint(greaterThanOrEqualTo: iconBg.bottomAnchor, constant: 16),
            divider.topAnchor.constraint(greaterThanOrEqualTo: addrLabel.bottomAnchor, constant: 12),
            divider.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            // Chin anchored below divider, fills card bottom
            chin.topAnchor.constraint(equalTo: divider.bottomAnchor),
            chin.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            chin.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            chin.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            chin.heightAnchor.constraint(equalToConstant: 50),

            // Button stack fills chin with inset padding
            chinStack.leadingAnchor.constraint(equalTo: chin.leadingAnchor, constant: 12),
            chinStack.trailingAnchor.constraint(equalTo: chin.trailingAnchor, constant: -12),
            chinStack.topAnchor.constraint(equalTo: chin.topAnchor, constant: 8),
            chinStack.bottomAnchor.constraint(equalTo: chin.bottomAnchor, constant: -8),
        ])

        return card
    }

    private func makeChinButton(title: String, foreground: UIColor?, tag: Int, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.88)
        config.baseForegroundColor = foreground
        config.cornerStyle         = .capsule
        config.contentInsets       = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attrs in
            var a = attrs; a.font = UIFont.karla(.semibold, size: 14); return a
        }
        config.title = title
        let btn = UIButton(configuration: config)
        btn.tag = tag
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    // MARK: - Actions

    @objc private func setTapped(_ sender: UIButton) {
        let index = sender.tag
        settingIndex = index
        let label = locations[index].label

        let sheet = UIAlertController(title: "Set \(label)", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Use Current Location", style: .default) { [weak self] _ in
            self?.useCurrentLocation(for: index)
        })
        sheet.addAction(UIAlertAction(title: "Enter Address", style: .default) { [weak self] _ in
            self?.promptForAddress(index: index)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.settingIndex = nil
        })

        // iPad popover anchor
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = sender
            pop.sourceRect = sender.bounds
        }

        present(sheet, animated: true)
    }

    private func useCurrentLocation(for index: Int) {
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            markLocating(index: index)
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            let alert = UIAlertController(
                title: "Location Access Required",
                message: "Go to Settings › Privacy › Location Services to enable location for this app.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        @unknown default:
            locationManager.requestWhenInUseAuthorization()
        }
    }

    private func promptForAddress(index: Int) {
        let alert = UIAlertController(
            title: "Enter Address",
            message: "Type the address for \(locations[index].label)",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder            = "Street, City, State…"
            tf.font                   = UIFont.karla(.regular, size: 14)
            tf.autocorrectionType     = .no
            tf.autocapitalizationType = .words
            tf.returnKeyType          = .done
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let text = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !text.isEmpty else { return }
            self.geocodeAddress(text, for: index)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func geocodeAddress(_ address: String, for index: Int) {
        locations[index].addressName = "Looking up…"
        rebuildCards()

        Task { @MainActor in
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = address
            if let response = try? await MKLocalSearch(request: req).start(),
               let item = response.mapItems.first {
                let loc = item.location
                self.locations[index].latitude    = loc.coordinate.latitude
                self.locations[index].longitude   = loc.coordinate.longitude
                self.locations[index].addressName = item.name ?? item.address?.shortAddress ?? address
            } else {
                self.locations[index].addressName = "Address not found — try again"
            }
            self.saveLocations()
            self.rebuildCards()
        }
    }

    private func markLocating(index: Int) {
        guard index < locations.count else { return }
        locations[index].addressName = "Locating…"
        rebuildCards()
    }

    @objc private func deleteTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index < locations.count, !locations[index].isBuiltIn else { return }
        locations.remove(at: index)
        saveLocations()
        rebuildCards()
    }

    @objc private func addLocationTapped() {
        let alert = UIAlertController(title: "Add Location", message: "Give this place a name", preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder            = "e.g. Parents' House, Gym, Cabin…"
            tf.font                   = UIFont.karla(.regular, size: 14)
            tf.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self,
                  let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespaces),
                  !name.isEmpty else { return }
            let newLoc = SavedLocation(id: UUID().uuidString, label: name,
                                       addressName: nil, latitude: nil, longitude: nil,
                                       isBuiltIn: false)
            self.locations.append(newLoc)
            self.saveLocations()
            self.rebuildCards()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationsViewController: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        guard (status == .authorizedAlways || status == .authorizedWhenInUse),
              let idx = settingIndex else { return }
        markLocating(index: idx)
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.first, let idx = settingIndex else { return }
        settingIndex = nil
        locations[idx].latitude  = loc.coordinate.latitude
        locations[idx].longitude = loc.coordinate.longitude

        Task { @MainActor in
            if let request = MKReverseGeocodingRequest(location: loc),
               let mapItem = (try? await request.mapItems)?.first {
                self.locations[idx].addressName = mapItem.name
                    ?? mapItem.address?.shortAddress
                    ?? "Unknown"
            } else {
                self.locations[idx].addressName = String(
                    format: "%.4f, %.4f", loc.coordinate.latitude, loc.coordinate.longitude)
            }
            self.saveLocations()
            self.rebuildCards()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let idx = settingIndex else { return }
        settingIndex = nil
        locations[idx].addressName = "Failed — try again"
        rebuildCards()
    }
}
