import UIKit
import PhotosUI
import CoreLocation
import MapKit

protocol ProfileViewControllerDelegate: AnyObject {
    func profileViewController(_ vc: ProfileViewController, didUpdatePhoto image: UIImage)
}

class ProfileViewController: UIViewController {

    weak var delegate: ProfileViewControllerDelegate?
    var initialImage: UIImage?

    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let photoImageView = UIImageView()
    private var locationsSubtitleLabel: UILabel!

    var placeCandidates: [PlaceSummary] = []

    private let gridColors: [UIColor] = [
        UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1),
        UIColor(red: 0.79, green: 0.87, blue: 0.82, alpha: 1),
        UIColor(red: 0.56, green: 0.65, blue: 0.76, alpha: 1),
        UIColor(red: 0.82, green: 0.70, blue: 0.62, alpha: 1),
        UIColor(red: 0.65, green: 0.72, blue: 0.85, alpha: 1),
        UIColor(red: 0.92, green: 0.87, blue: 0.78, alpha: 1),
        UIColor(red: 0.76, green: 0.88, blue: 0.80, alpha: 1),
        UIColor(red: 0.82, green: 0.78, blue: 0.90, alpha: 1),
    ]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        setupScrollLayout()
        setupContent()
        if let image = initialImage {
            photoImageView.image = image
        }
    }

    // MARK: - Scroll shell

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

        // — Close button —
        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setImage(UIImage(systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)), for: .normal)
        closeBtn.tintColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.50)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        contentView.addSubview(closeBtn)

        // — Photo ring —
        let photoRing = UIView()
        photoRing.translatesAutoresizingMaskIntoConstraints = false
        photoRing.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.22)
        photoRing.layer.cornerRadius = 48
        photoRing.layer.borderWidth  = 1.5
        photoRing.layer.borderColor  = UIColor(named: "FogBackground")?.withAlphaComponent(0.22).cgColor
        photoRing.clipsToBounds      = true
        photoRing.isUserInteractionEnabled = true
        photoRing.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))
        contentView.addSubview(photoRing)

        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.contentMode = .scaleAspectFill
        photoRing.addSubview(photoImageView)

        // — Camera badge —
        let badge = UIView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.backgroundColor    = UIColor(named: "ClayAccent")
        badge.layer.cornerRadius = 14
        badge.layer.borderWidth  = 2
        badge.layer.borderColor  = UIColor(named: "DustySage")?.cgColor
        badge.isUserInteractionEnabled = false
        contentView.addSubview(badge)

        let cameraIcon = UIImageView(image: UIImage(systemName: "camera.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .regular)))
        cameraIcon.translatesAutoresizingMaskIntoConstraints = false
        cameraIcon.tintColor     = UIColor(named: "FogBackground")
        cameraIcon.contentMode   = .scaleAspectFit
        badge.addSubview(cameraIcon)

        // — Name —
        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.text          = "Lucas Waunn"
        nameLabel.font          = .fraunces(.bold, size: 24)
        nameLabel.textColor     = UIColor(named: "FogBackground")
        nameLabel.textAlignment = .center
        contentView.addSubview(nameLabel)

        // — Bio —
        let bioLabel = UILabel()
        bioLabel.translatesAutoresizingMaskIntoConstraints = false
        bioLabel.text          = "Collecting firsts, one adventure at a time.\nChicago, IL"
        bioLabel.font          = .karla(.regular, size: 14)
        bioLabel.textColor     = UIColor(named: "FogBackground")?.withAlphaComponent(0.58)
        bioLabel.textAlignment = .center
        bioLabel.numberOfLines = 0
        bioLabel.isUserInteractionEnabled = true
        bioLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(bioTapped)))
        contentView.addSubview(bioLabel)

        let editHint = UILabel()
        editHint.translatesAutoresizingMaskIntoConstraints = false
        editHint.text          = "tap to edit"
        editHint.font          = .karla(.regular, size: 11)
        editHint.textColor     = UIColor(named: "FogBackground")?.withAlphaComponent(0.28)
        editHint.textAlignment = .center
        contentView.addSubview(editHint)

        // — Stats row —
        let statsStack = makeStatsRow()
        contentView.addSubview(statsStack)

        // — Divider —
        let divider = UIView()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.15)
        contentView.addSubview(divider)

        // — Section header —
        let sectionLabel = UILabel()
        sectionLabel.translatesAutoresizingMaskIntoConstraints = false
        sectionLabel.attributedText = NSAttributedString(string: "RECENT FIRSTS", attributes: [
            .font: UIFont.karla(.semibold, size: 12),
            .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.55) ?? UIColor.white,
            .kern: 1.5,
        ])
        contentView.addSubview(sectionLabel)

        // — Grid —
        let grid = buildGrid()
        contentView.addSubview(grid)

        // — Locations card —
        let locationsCard = buildLocationsCard()
        contentView.addSubview(locationsCard)

        NSLayoutConstraint.activate([
            // close
            closeBtn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            closeBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            closeBtn.widthAnchor.constraint(equalToConstant: 28),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),

            // photo ring
            photoRing.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 56),
            photoRing.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            photoRing.widthAnchor.constraint(equalToConstant: 96),
            photoRing.heightAnchor.constraint(equalToConstant: 96),

            photoImageView.topAnchor.constraint(equalTo: photoRing.topAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: photoRing.bottomAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: photoRing.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: photoRing.trailingAnchor),

            // badge
            badge.trailingAnchor.constraint(equalTo: photoRing.trailingAnchor, constant: 4),
            badge.bottomAnchor.constraint(equalTo: photoRing.bottomAnchor, constant: 4),
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28),

            cameraIcon.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            cameraIcon.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            cameraIcon.widthAnchor.constraint(equalToConstant: 14),
            cameraIcon.heightAnchor.constraint(equalToConstant: 14),

            // name
            nameLabel.topAnchor.constraint(equalTo: photoRing.bottomAnchor, constant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // bio
            bioLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            bioLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            bioLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),

            editHint.topAnchor.constraint(equalTo: bioLabel.bottomAnchor, constant: 5),
            editHint.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // stats
            statsStack.topAnchor.constraint(equalTo: editHint.bottomAnchor, constant: 26),
            statsStack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // locations card
            locationsCard.topAnchor.constraint(equalTo: statsStack.bottomAnchor, constant: 20),
            locationsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            locationsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            // divider
            divider.topAnchor.constraint(equalTo: locationsCard.bottomAnchor, constant: 16),
            divider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            divider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            divider.heightAnchor.constraint(equalToConstant: 0.5),

            // section header
            sectionLabel.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 20),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // grid
            grid.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14),
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            grid.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -36),
        ])
    }

    private func makeStatsRow() -> UIStackView {
        let currentYear = Calendar.current.component(.year, from: Date())
        let thisYearCount = placeCandidates.filter {
            Calendar.current.component(.year, from: $0.firstVisitDate) == currentYear
        }.count

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis      = .horizontal
        stack.spacing   = 36
        stack.alignment = .center

        for (value, label) in [("\(placeCandidates.count)", "Firsts"), ("\(thisYearCount)", "This Year"), ("—", "Countries")] {
            let col = UIStackView()
            col.axis      = .vertical
            col.alignment = .center
            col.spacing   = 2

            let val = UILabel()
            val.text      = value
            val.font      = .fraunces(.bold, size: 22)
            val.textColor = UIColor(named: "FogBackground")

            let lbl = UILabel()
            lbl.text      = label
            lbl.font      = .karla(.regular, size: 12)
            lbl.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.48)

            col.addArrangedSubview(val)
            col.addArrangedSubview(lbl)
            stack.addArrangedSubview(col)
        }
        return stack
    }

    // MARK: - Locations card

    private func buildLocationsCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor    = UIColor(named: "FogBackground")?.withAlphaComponent(0.10)
        card.layer.cornerRadius = 14
        card.layer.borderWidth  = 0.5
        card.layer.borderColor  = UIColor(named: "FogBackground")?.withAlphaComponent(0.18).cgColor
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(locationsTapped)))

        let pinIcon = UIImageView(image: UIImage(systemName: "mappin.and.ellipse",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .regular)))
        pinIcon.translatesAutoresizingMaskIntoConstraints = false
        pinIcon.tintColor   = UIColor(named: "ClayAccent")
        pinIcon.contentMode = .scaleAspectFit
        card.addSubview(pinIcon)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text      = "Locations"
        titleLabel.font      = .karla(.semibold, size: 13)
        titleLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.80)
        card.addSubview(titleLabel)

        locationsSubtitleLabel = UILabel()
        locationsSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        locationsSubtitleLabel.text          = locationsSubtitle()
        locationsSubtitleLabel.font          = .karla(.regular, size: 12)
        locationsSubtitleLabel.textColor     = UIColor(named: "FogBackground")?.withAlphaComponent(0.48)
        locationsSubtitleLabel.numberOfLines = 1
        card.addSubview(locationsSubtitleLabel)

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor   = UIColor(named: "FogBackground")?.withAlphaComponent(0.30)
        chevron.contentMode = .scaleAspectFit
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            pinIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            pinIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            pinIcon.widthAnchor.constraint(equalToConstant: 18),
            pinIcon.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.leadingAnchor.constraint(equalTo: pinIcon.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            locationsSubtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            locationsSubtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            locationsSubtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            locationsSubtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
        ])

        return card
    }

    private func locationsSubtitle() -> String {
        let all = SavedLocation.loadAll()
        let setNames = all.filter { $0.isSet }.map { $0.label }
        return setNames.isEmpty ? "Tap to manage" : setNames.joined(separator: " · ")
    }

    private func updateLocationsCard() {
        locationsSubtitleLabel?.text = locationsSubtitle()
    }

    // MARK: - Grid

    private func buildGrid() -> UIView {
        if placeCandidates.isEmpty {
            let wrapper = UIView()
            wrapper.translatesAutoresizingMaskIntoConstraints = false
            let label = UILabel()
            label.translatesAutoresizingMaskIntoConstraints = false
            label.text          = "No places tracked yet.\nExplore somewhere new!"
            label.font          = .karla(.regular, size: 14)
            label.textColor     = UIColor(named: "FogBackground")?.withAlphaComponent(0.40)
            label.textAlignment = .center
            label.numberOfLines = 0
            wrapper.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: wrapper.centerXAnchor),
                label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 24),
                label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor),
                label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
                label.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -24),
            ])
            return wrapper
        }

        let vStack = UIStackView()
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.axis    = .vertical
        vStack.spacing = 10

        var i = 0
        while i < placeCandidates.count {
            let row = UIStackView()
            row.axis         = .horizontal
            row.spacing      = 10
            row.distribution = .fillEqually
            row.heightAnchor.constraint(equalToConstant: 148).isActive = true

            row.addArrangedSubview(makeGridCell(placeCandidates[i], color: gridColors[i % gridColors.count]))

            if i + 1 < placeCandidates.count {
                row.addArrangedSubview(makeGridCell(placeCandidates[i + 1], color: gridColors[(i + 1) % gridColors.count]))
            } else {
                row.addArrangedSubview(UIView())
            }

            vStack.addArrangedSubview(row)
            i += 2
        }
        return vStack
    }

    private func makeGridCell(_ candidate: PlaceSummary, color: UIColor) -> UIView {
        let card = UIView()
        card.backgroundColor    = color
        card.layer.cornerRadius = 16
        card.clipsToBounds      = true

        let scrim = UIView()
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.40)
        card.addSubview(scrim)

        let visitText = "\(candidate.visitCount) visit\(candidate.visitCount == 1 ? "" : "s")".uppercased()
        let catLabel = UILabel()
        catLabel.translatesAutoresizingMaskIntoConstraints = false
        catLabel.attributedText = NSAttributedString(string: visitText, attributes: [
            .font: UIFont.karla(.semibold, size: 9),
            .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.72) ?? UIColor.white,
            .kern: 0.8,
        ])
        card.addSubview(catLabel)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text          = candidate.placeName
        titleLabel.font          = .fraunces(.regular, size: 14)
        titleLabel.textColor     = UIColor(named: "FogBackground")
        titleLabel.numberOfLines = 2
        card.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            scrim.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scrim.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            scrim.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            scrim.heightAnchor.constraint(equalTo: card.heightAnchor, multiplier: 0.55),

            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            titleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),

            catLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            catLabel.bottomAnchor.constraint(equalTo: titleLabel.topAnchor, constant: -3),
        ])

        return card
    }

    // MARK: - Actions

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func photoTapped() {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter         = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func locationsTapped() {
        let locVC = LocationsViewController()
        locVC.delegate = self
        locVC.modalPresentationStyle = .pageSheet
        if let sheet = locVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(locVC, animated: true)
    }

    @objc private func bioTapped() {
        let alert = UIAlertController(title: "Edit Bio", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text        = "Collecting firsts, one adventure at a time.\nChicago, IL"
            tf.font        = UIFont.karla(.regular, size: 14)
            tf.placeholder = "Write something about yourself…"
        }
        alert.addAction(UIAlertAction(title: "Save", style: .default))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - LocationsViewControllerDelegate

extension ProfileViewController: LocationsViewControllerDelegate {
    func locationsDidUpdate() {
        updateLocationsCard()
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }

        // PHImageManager with .aspectFill gives a pre-cropped square image, avoiding
        // EXIF orientation issues that cause squishing on real devices.
        if let identifier = result.assetIdentifier {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = assets.firstObject {
                let opts = PHImageRequestOptions()
                opts.deliveryMode          = .highQualityFormat
                opts.isNetworkAccessAllowed = true
                PHImageManager.default().requestImage(
                    for: asset,
                    targetSize: CGSize(width: 400, height: 400),
                    contentMode: .aspectFill,
                    options: opts
                ) { [weak self] image, info in
                    guard let self, let image,
                          (info?[PHImageResultIsDegradedKey] as? Bool) != true else { return }
                    DispatchQueue.main.async {
                        self.photoImageView.image = image
                        self.delegate?.profileViewController(self, didUpdatePhoto: image)
                    }
                }
                return
            }
        }

        // Fallback if no asset identifier (e.g. iCloud-only photo)
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self, let image = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self.photoImageView.image = image
                self.delegate?.profileViewController(self, didUpdatePhoto: image)
            }
        }
    }
}
