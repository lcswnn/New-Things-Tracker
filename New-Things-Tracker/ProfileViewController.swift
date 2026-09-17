import UIKit
import PhotosUI

protocol ProfileViewControllerDelegate: AnyObject {
    func profileViewController(_ vc: ProfileViewController, didUpdatePhoto image: UIImage)
}

class ProfileViewController: UIViewController {

    weak var delegate: ProfileViewControllerDelegate?
    var initialImage: UIImage?

    private let scrollView  = UIScrollView()
    private let contentView = UIView()
    private let photoImageView = UIImageView()

    private let gridItems: [(title: String, category: String, color: UIColor)] = [
        ("Randolph Street Market",     "Festival",      UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1)),
        ("Hot Air Balloon Ride",       "Adventure",     UIColor(red: 0.79, green: 0.87, blue: 0.82, alpha: 1)),
        ("First Jazz Concert",         "Music",         UIColor(red: 0.56, green: 0.65, blue: 0.76, alpha: 1)),
        ("Drive-In Movie Night",       "Entertainment", UIColor(red: 0.82, green: 0.70, blue: 0.62, alpha: 1)),
        ("Green Mill Cocktail Lounge", "Music",         UIColor(red: 0.65, green: 0.72, blue: 0.85, alpha: 1)),
        ("Lou Mitchell's Diner",       "Food",          UIColor(red: 0.92, green: 0.87, blue: 0.78, alpha: 1)),
        ("Millennium Park Run",        "Fitness",       UIColor(red: 0.76, green: 0.88, blue: 0.80, alpha: 1)),
        ("Chicago Architecture Tour",  "Culture",       UIColor(red: 0.82, green: 0.78, blue: 0.90, alpha: 1)),
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
        photoRing.isUserInteractionEnabled = true
        photoRing.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))
        contentView.addSubview(photoRing)

        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.contentMode   = .scaleAspectFill
        photoImageView.clipsToBounds = true
        photoImageView.layer.cornerRadius = 46
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

            photoImageView.topAnchor.constraint(equalTo: photoRing.topAnchor, constant: 1),
            photoImageView.bottomAnchor.constraint(equalTo: photoRing.bottomAnchor, constant: -1),
            photoImageView.leadingAnchor.constraint(equalTo: photoRing.leadingAnchor, constant: 1),
            photoImageView.trailingAnchor.constraint(equalTo: photoRing.trailingAnchor, constant: -1),

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

            // divider
            divider.topAnchor.constraint(equalTo: statsStack.bottomAnchor, constant: 26),
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
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis      = .horizontal
        stack.spacing   = 36
        stack.alignment = .center

        for (value, label) in [("47", "Firsts"), ("12", "This Year"), ("8", "Countries")] {
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

    // MARK: - Grid

    private func buildGrid() -> UIStackView {
        let vStack = UIStackView()
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.axis    = .vertical
        vStack.spacing = 10

        var i = 0
        while i < gridItems.count {
            let row = UIStackView()
            row.axis         = .horizontal
            row.spacing      = 10
            row.distribution = .fillEqually
            row.heightAnchor.constraint(equalToConstant: 148).isActive = true

            row.addArrangedSubview(makeGridCell(gridItems[i]))

            if i + 1 < gridItems.count {
                row.addArrangedSubview(makeGridCell(gridItems[i + 1]))
            } else {
                row.addArrangedSubview(UIView())
            }

            vStack.addArrangedSubview(row)
            i += 2
        }
        return vStack
    }

    private func makeGridCell(_ item: (title: String, category: String, color: UIColor)) -> UIView {
        let card = UIView()
        card.backgroundColor    = item.color
        card.layer.cornerRadius = 16
        card.clipsToBounds      = true

        // Bottom scrim so text is always legible
        let scrim = UIView()
        scrim.translatesAutoresizingMaskIntoConstraints = false
        scrim.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.40)
        card.addSubview(scrim)

        let catLabel = UILabel()
        catLabel.translatesAutoresizingMaskIntoConstraints = false
        catLabel.attributedText = NSAttributedString(string: item.category.uppercased(), attributes: [
            .font: UIFont.karla(.semibold, size: 9),
            .foregroundColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.72) ?? UIColor.white,
            .kern: 0.8,
        ])
        card.addSubview(catLabel)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text          = item.title
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
        var config = PHPickerConfiguration()
        config.filter         = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
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

// MARK: - PHPickerViewControllerDelegate

extension ProfileViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            guard let self, let image = obj as? UIImage else { return }
            DispatchQueue.main.async {
                self.photoImageView.image = image
                self.delegate?.profileViewController(self, didUpdatePhoto: image)
            }
        }
    }
}
