import UIKit
import Photos
import SwiftData

extension UIFont {
    // Fraunces — serif display font for titles and headers
    static func fraunces(_ weight: UIFont.Weight = .regular, size: CGFloat) -> UIFont {
        let name: String
        switch weight {
        case .semibold:                         name = "Fraunces72pt-SemiBold"
        case .bold, .heavy, .black:             name = "Fraunces72pt-Bold"
        default:                                name = "Fraunces72pt-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    // Fraunces Italic — the serif display style used for screen titles/greetings across the app
    static func frauncesItalic(size: CGFloat) -> UIFont {
        UIFont(name: "Fraunces72pt-Italic", size: size) ?? .italicSystemFont(ofSize: size)
    }

    static func frauncesBoldItalic(size: CGFloat) -> UIFont {
        UIFont(name: "Fraunces72pt-BoldItalic", size: size) ?? .italicSystemFont(ofSize: size)
    }

    // Karla — sans-serif for body text, labels, and subtitles
    static func karla(_ weight: UIFont.Weight = .regular, size: CGFloat) -> UIFont {
        let name: String
        switch weight {
        case .medium:                           name = "Karla-Medium"
        case .semibold:                         name = "Karla-SemiBold"
        case .bold, .heavy, .black:             name = "Karla-Bold"
        default:                                name = "Karla-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}

struct FirstCardViewModel {
    let title: String
    let location: String
    let category: String
    let date: String
    let duration: String
    let photoCount: Int
    let extraPhotos: Int
    let largePhotoColor: UIColor
    let smallPhotoColor: UIColor
    let photoLocalIDs: [String]
    // Overlay pill text for the hero card, e.g. "1 year ago today" or "Most recent first"
    var badgeText: String = "Most recent first"
}

class FirstCardCell: UITableViewCell {
    static let identifier = "FirstCardCell"

    private let cardContainer = UIView()
    private let photoBackground = UIView()
    private let photoImageView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let gradientView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let badgePill = UIView()
    private let badgeLabel = UILabel()
    private let captionLabel = UILabel()

    private var imageRequestID: PHImageRequestID?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCard()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCard() {
        backgroundColor = .clear
        selectionStyle = .none

        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.backgroundColor = UIColor(named: "FogBackground")
        cardContainer.layer.cornerRadius = 22
        cardContainer.clipsToBounds = true
        contentView.addSubview(cardContainer)

        photoBackground.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(photoBackground)

        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        placeholderIcon.image = UIImage(systemName: "photo",
                                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 32, weight: .medium))
        placeholderIcon.tintColor = UIColor.black.withAlphaComponent(0.20)
        placeholderIcon.contentMode = .scaleAspectFit
        photoBackground.addSubview(placeholderIcon)

        photoImageView.translatesAutoresizingMaskIntoConstraints = false
        photoImageView.contentMode = .scaleAspectFill
        photoImageView.clipsToBounds = true
        cardContainer.addSubview(photoImageView)

        // Bottom gradient so the caption stays legible over any photo
        gradientView.translatesAutoresizingMaskIntoConstraints = false
        gradientView.isUserInteractionEnabled = false
        gradientLayer.colors = [UIColor.black.withAlphaComponent(0).cgColor, UIColor.black.withAlphaComponent(0.68).cgColor]
        gradientLayer.locations = [0, 1]
        gradientView.layer.addSublayer(gradientLayer)
        cardContainer.addSubview(gradientView)

        badgePill.translatesAutoresizingMaskIntoConstraints = false
        badgePill.backgroundColor = UIColor(named: "ClayAccent")
        badgePill.layer.cornerRadius = 14
        cardContainer.addSubview(badgePill)

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.font = UIFont.karla(.semibold, size: 13)
        badgeLabel.textColor = .white
        badgePill.addSubview(badgeLabel)

        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.font = UIFont.frauncesItalic(size: 19)
        captionLabel.textColor = .white
        captionLabel.numberOfLines = 2
        cardContainer.addSubview(captionLabel)

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardContainer.heightAnchor.constraint(equalToConstant: 260),

            photoBackground.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            photoBackground.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            photoBackground.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            photoBackground.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),

            placeholderIcon.centerXAnchor.constraint(equalTo: photoBackground.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: photoBackground.centerYAnchor),

            photoImageView.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            photoImageView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            photoImageView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            photoImageView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),

            gradientView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            gradientView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            gradientView.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),
            gradientView.heightAnchor.constraint(equalTo: cardContainer.heightAnchor, multiplier: 0.55),

            badgePill.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 16),
            badgePill.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),

            badgeLabel.topAnchor.constraint(equalTo: badgePill.topAnchor, constant: 7),
            badgeLabel.bottomAnchor.constraint(equalTo: badgePill.bottomAnchor, constant: -7),
            badgeLabel.leadingAnchor.constraint(equalTo: badgePill.leadingAnchor, constant: 14),
            badgeLabel.trailingAnchor.constraint(equalTo: badgePill.trailingAnchor, constant: -14),

            captionLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 18),
            captionLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -18),
            captionLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -18),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = gradientView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelImageRequests()
        photoImageView.image = nil
    }

    func configure(with first: FirstCardViewModel) {
        cancelImageRequests()
        photoImageView.image = nil

        photoBackground.backgroundColor = first.largePhotoColor
        let ids = first.photoLocalIDs
        placeholderIcon.isHidden = !ids.isEmpty
        if let localID = ids.first {
            imageRequestID = loadPhoto(localID, into: photoImageView, pointSize: CGSize(width: 700, height: 460))
        }

        badgeLabel.text = first.badgeText
        captionLabel.text = "Your first visit to \(first.title)"
    }

    private func cancelImageRequests() {
        if let id = imageRequestID { PHImageManager.default().cancelImageRequest(id); imageRequestID = nil }
    }

    @discardableResult
    private func loadPhoto(_ localID: String, into imageView: UIImageView, pointSize: CGSize) -> PHImageRequestID? {
        let scale      = traitCollection.displayScale
        let pixelSize  = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let assets     = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        guard let asset = assets.firstObject else { return nil }
        let opts = PHImageRequestOptions()
        opts.deliveryMode          = .opportunistic
        opts.isNetworkAccessAllowed = true
        opts.resizeMode            = .fast
        return PHImageManager.default().requestImage(
            for: asset, targetSize: pixelSize, contentMode: .aspectFill, options: opts
        ) { [weak imageView] image, _ in
            DispatchQueue.main.async { imageView?.image = image }
        }
    }
}

// MARK: - PastFirstRowCell

// Collapsed row used in the "Past Firsts" section — same info as FirstCardCell, without the big photo layout.
class PastFirstRowCell: UITableViewCell {
    static let identifier = "PastFirstRowCell"

    private let card = UIView()
    private let swatch = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let chevron = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        contentView.addSubview(card)

        swatch.translatesAutoresizingMaskIntoConstraints = false
        swatch.layer.cornerRadius = 10
        swatch.clipsToBounds = true
        card.addSubview(swatch)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .center
        iconView.tintColor = UIColor(named: "ClayAccent")
        iconView.isHidden = true
        swatch.addSubview(iconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .fraunces(.semibold, size: 16)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 1
        card.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .karla(.regular, size: 13)
        subtitleLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.5)
        subtitleLabel.numberOfLines = 1
        card.addSubview(subtitleLabel)

        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.image = UIImage(systemName: "chevron.right",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        chevron.tintColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.25)
        chevron.contentMode = .scaleAspectFit
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            swatch.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            swatch.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 40),
            swatch.heightAnchor.constraint(equalToConstant: 40),
            swatch.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),
            swatch.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),

            iconView.centerXAnchor.constraint(equalTo: swatch.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: swatch.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),

            titleLabel.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
        ])
    }

    func configure(with first: FirstCardViewModel) {
        swatch.backgroundColor = first.largePhotoColor
        iconView.isHidden = true
        chevron.isHidden = false
        titleLabel.text = first.title
        subtitleLabel.text = "\(first.date) · \(first.location)"
    }

    // Used for the "needs your input" review rows — an icon swatch instead of a photo color, no chevron.
    func configure(icon: UIImage?, title: String, subtitle: String) {
        swatch.backgroundColor = UIColor(named: "ClayAccent")?.withAlphaComponent(0.16)
        iconView.image = icon
        iconView.isHidden = false
        chevron.isHidden = true
        titleLabel.text = title
        subtitleLabel.text = subtitle
    }
}

// MARK: - Occasion model

struct Occasion {
    let label: String
    let location: String
    let category: String
    let duration: String
    let photoCount: Int
    let isNew: Bool
}

// MARK: - ReviewItem model

struct ReviewItem {
    let id: PersistentIdentifier
    let label: String
    let date: String
    let reason: String
    let photoLocalIDs: [String]
}

// MARK: - OccasionCell

class OccasionCell: UITableViewCell {
    static let identifier = "OccasionCell"

    private let card = UIView()
    private let newBadge = UIView()
    private let newBadgeLabel = UILabel()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let photoContainer = UIView()
    private let photoLabel = UILabel()

    private var titleLeadingNew: NSLayoutConstraint!
    private var titleLeadingNormal: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        contentView.addSubview(card)

        newBadge.translatesAutoresizingMaskIntoConstraints = false
        newBadge.backgroundColor = UIColor(named: "ClayAccent")
        newBadge.layer.cornerRadius = 9
        card.addSubview(newBadge)

        newBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        newBadgeLabel.text = "NEW"
        newBadgeLabel.font = .karla(.bold, size: 10)
        newBadgeLabel.textColor = UIColor(named: "FogBackground")
        newBadge.addSubview(newBadgeLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .fraunces(.regular, size: 18)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 1
        card.addSubview(titleLabel)

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .karla(.regular, size: 13)
        detailLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.45)
        card.addSubview(detailLabel)

        photoContainer.translatesAutoresizingMaskIntoConstraints = false
        photoContainer.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.07)
        photoContainer.layer.cornerRadius = 10
        card.addSubview(photoContainer)

        photoLabel.translatesAutoresizingMaskIntoConstraints = false
        photoLabel.font = .karla(.medium, size: 12)
        photoLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50)
        photoContainer.addSubview(photoLabel)

        titleLeadingNew    = titleLabel.leadingAnchor.constraint(equalTo: newBadge.trailingAnchor, constant: 10)
        titleLeadingNormal = titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            newBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            newBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            newBadge.widthAnchor.constraint(equalToConstant: 36),
            newBadge.heightAnchor.constraint(equalToConstant: 18),

            newBadgeLabel.centerXAnchor.constraint(equalTo: newBadge.centerXAnchor),
            newBadgeLabel.centerYAnchor.constraint(equalTo: newBadge.centerYAnchor),

            photoContainer.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            photoContainer.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            photoLabel.topAnchor.constraint(equalTo: photoContainer.topAnchor, constant: 4),
            photoLabel.bottomAnchor.constraint(equalTo: photoContainer.bottomAnchor, constant: -4),
            photoLabel.leadingAnchor.constraint(equalTo: photoContainer.leadingAnchor, constant: 8),
            photoLabel.trailingAnchor.constraint(equalTo: photoContainer.trailingAnchor, constant: -8),

            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: photoContainer.leadingAnchor, constant: -8),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
    }

    func configure(with occasion: Occasion) {
        titleLabel.text = occasion.label
        detailLabel.text = "\(occasion.location) · \(occasion.duration) · \(occasion.category)"

        newBadge.isHidden = !occasion.isNew
        titleLeadingNew.isActive = occasion.isNew
        titleLeadingNormal.isActive = !occasion.isNew

        if occasion.photoCount > 0 {
            photoLabel.text = "📷 \(occasion.photoCount)"
            photoContainer.isHidden = false
        } else {
            photoContainer.isHidden = true
        }
    }
}

// MARK: - HomeStatsFooterCell

// Bottom-of-feed summary card: total/this-year/cities tile row plus a link into the year's collection.
class HomeStatsFooterCell: UITableViewCell {
    static let identifier = "HomeStatsFooterCell"

    var onCollectionTapped: (() -> Void)?

    private let card = UIView()
    private let totalValueLabel = UILabel()
    private let yearValueLabel = UILabel()
    private let citiesValueLabel = UILabel()
    private let collectionButton = UIButton(type: .system)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 20
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        contentView.addSubview(card)

        func makeTile(valueLabel: UILabel, caption: String) -> UIView {
            let tile = UIView()
            tile.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.translatesAutoresizingMaskIntoConstraints = false
            valueLabel.font = .fraunces(.bold, size: 26)
            valueLabel.textColor = UIColor(named: "ClayAccent")
            valueLabel.textAlignment = .center
            let captionLabel = UILabel()
            captionLabel.translatesAutoresizingMaskIntoConstraints = false
            captionLabel.text = caption
            captionLabel.font = .karla(.regular, size: 12)
            captionLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50)
            captionLabel.textAlignment = .center
            tile.addSubview(valueLabel)
            tile.addSubview(captionLabel)
            NSLayoutConstraint.activate([
                valueLabel.topAnchor.constraint(equalTo: tile.topAnchor),
                valueLabel.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                captionLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 2),
                captionLabel.centerXAnchor.constraint(equalTo: tile.centerXAnchor),
                captionLabel.bottomAnchor.constraint(equalTo: tile.bottomAnchor),
            ])
            return tile
        }

        let tileStack = UIStackView(arrangedSubviews: [
            makeTile(valueLabel: totalValueLabel, caption: "Firsts"),
            makeTile(valueLabel: yearValueLabel, caption: "this year"),
            makeTile(valueLabel: citiesValueLabel, caption: "cities"),
        ])
        tileStack.translatesAutoresizingMaskIntoConstraints = false
        tileStack.axis = .horizontal
        tileStack.distribution = .fillEqually
        card.addSubview(tileStack)

        var config = UIButton.Configuration.plain()
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16)
        config.baseForegroundColor = UIColor(named: "DeepPineInk")
        config.image = UIImage(systemName: "chevron.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        config.imagePlacement = .trailing
        config.imagePadding = 8
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .karla(.semibold, size: 15)
            return outgoing
        }
        collectionButton.configuration = config
        collectionButton.translatesAutoresizingMaskIntoConstraints = false
        collectionButton.backgroundColor = UIColor(named: "DustySage")?.withAlphaComponent(0.18)
        collectionButton.layer.cornerRadius = 14
        collectionButton.contentHorizontalAlignment = .fill
        collectionButton.addTarget(self, action: #selector(collectionTapped), for: .touchUpInside)
        card.addSubview(collectionButton)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            tileStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            tileStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            tileStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            collectionButton.topAnchor.constraint(equalTo: tileStack.bottomAnchor, constant: 18),
            collectionButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            collectionButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            collectionButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
    }

    @objc private func collectionTapped() { onCollectionTapped?() }

    func configure(total: Int, thisYear: Int, cities: Int, year: Int) {
        totalValueLabel.text = "\(total)"
        yearValueLabel.text = "\(thisYear)"
        citiesValueLabel.text = "\(cities)"
        var config = collectionButton.configuration
        config?.title = "Your \(year) collection"
        collectionButton.configuration = config
    }
}
