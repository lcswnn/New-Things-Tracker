import UIKit

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

struct First {
    let title: String
    let location: String
    let category: String
    let date: String
    let duration: String
    let photoCount: Int
    let extraPhotos: Int
    let largePhotoColor: UIColor
    let smallPhotoColor: UIColor
}

class FirstCardCell: UITableViewCell {
    static let identifier = "FirstCardCell"

    private let cardContainer = UIView()
    private let largePhotoView = UIView()
    private let smallPhotoView = UIView()
    private let extraCountContainer = UIView()
    private let extraCountLabel = UILabel()
    private let largePhotoLabel = UILabel()
    private let smallPhotoLabel = UILabel()
    private let categoryContainer = UIView()
    private let categoryLabel = UILabel()
    private let dateLabel = UILabel()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

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
        cardContainer.layer.cornerRadius = 20
        cardContainer.clipsToBounds = true
        contentView.addSubview(cardContainer)

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
        ])

        // Photo section
        let photoSection = UIView()
        photoSection.translatesAutoresizingMaskIntoConstraints = false
        photoSection.clipsToBounds = true
        cardContainer.addSubview(photoSection)

        largePhotoView.translatesAutoresizingMaskIntoConstraints = false
        photoSection.addSubview(largePhotoView)

        largePhotoLabel.translatesAutoresizingMaskIntoConstraints = false
        largePhotoLabel.text = "PHOTO"
        largePhotoLabel.font = UIFont.karla(.medium, size: 12)
        largePhotoLabel.textColor = UIColor.black.withAlphaComponent(0.25)
        largePhotoLabel.textAlignment = .center
        largePhotoView.addSubview(largePhotoLabel)

        let rightColumn = UIView()
        rightColumn.translatesAutoresizingMaskIntoConstraints = false
        photoSection.addSubview(rightColumn)

        smallPhotoView.translatesAutoresizingMaskIntoConstraints = false
        rightColumn.addSubview(smallPhotoView)

        smallPhotoLabel.translatesAutoresizingMaskIntoConstraints = false
        smallPhotoLabel.text = "PHOTO"
        smallPhotoLabel.font = UIFont.karla(.medium, size: 10)
        smallPhotoLabel.textColor = UIColor.black.withAlphaComponent(0.25)
        smallPhotoLabel.textAlignment = .center
        smallPhotoView.addSubview(smallPhotoLabel)

        extraCountContainer.translatesAutoresizingMaskIntoConstraints = false
        extraCountContainer.backgroundColor = UIColor.black.withAlphaComponent(0.06)
        rightColumn.addSubview(extraCountContainer)

        extraCountLabel.translatesAutoresizingMaskIntoConstraints = false
        extraCountLabel.font = UIFont.karla(.medium, size: 17)
        extraCountLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.55)
        extraCountLabel.textAlignment = .center
        extraCountContainer.addSubview(extraCountLabel)

        // Info section
        let infoSection = UIView()
        infoSection.translatesAutoresizingMaskIntoConstraints = false
        cardContainer.addSubview(infoSection)

        categoryContainer.translatesAutoresizingMaskIntoConstraints = false
        categoryContainer.backgroundColor = .white.withAlphaComponent(0.7)
        categoryContainer.layer.cornerRadius = 13
        infoSection.addSubview(categoryContainer)

        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.font = UIFont.karla(.semibold, size: 13)
        categoryLabel.textColor = UIColor(named: "DeepPineInk")
        categoryContainer.addSubview(categoryLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.karla(.regular, size: 14)
        dateLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.55)
        infoSection.addSubview(dateLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.fraunces(.bold, size: 22)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 2
        infoSection.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.karla(.regular, size: 14)
        subtitleLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.45)
        infoSection.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            photoSection.topAnchor.constraint(equalTo: cardContainer.topAnchor),
            photoSection.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            photoSection.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            photoSection.heightAnchor.constraint(equalToConstant: 200),

            largePhotoView.topAnchor.constraint(equalTo: photoSection.topAnchor),
            largePhotoView.bottomAnchor.constraint(equalTo: photoSection.bottomAnchor),
            largePhotoView.leadingAnchor.constraint(equalTo: photoSection.leadingAnchor),
            largePhotoView.trailingAnchor.constraint(equalTo: rightColumn.leadingAnchor, constant: -2),

            largePhotoLabel.centerXAnchor.constraint(equalTo: largePhotoView.centerXAnchor),
            largePhotoLabel.centerYAnchor.constraint(equalTo: largePhotoView.centerYAnchor),

            rightColumn.topAnchor.constraint(equalTo: photoSection.topAnchor),
            rightColumn.bottomAnchor.constraint(equalTo: photoSection.bottomAnchor),
            rightColumn.trailingAnchor.constraint(equalTo: photoSection.trailingAnchor),
            rightColumn.widthAnchor.constraint(equalTo: photoSection.widthAnchor, multiplier: 0.35),

            smallPhotoView.topAnchor.constraint(equalTo: rightColumn.topAnchor),
            smallPhotoView.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
            smallPhotoView.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
            smallPhotoView.heightAnchor.constraint(equalTo: rightColumn.heightAnchor, multiplier: 0.5, constant: -1),

            smallPhotoLabel.centerXAnchor.constraint(equalTo: smallPhotoView.centerXAnchor),
            smallPhotoLabel.centerYAnchor.constraint(equalTo: smallPhotoView.centerYAnchor),

            extraCountContainer.topAnchor.constraint(equalTo: smallPhotoView.bottomAnchor, constant: 2),
            extraCountContainer.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
            extraCountContainer.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
            extraCountContainer.bottomAnchor.constraint(equalTo: rightColumn.bottomAnchor),

            extraCountLabel.centerXAnchor.constraint(equalTo: extraCountContainer.centerXAnchor),
            extraCountLabel.centerYAnchor.constraint(equalTo: extraCountContainer.centerYAnchor),

            infoSection.topAnchor.constraint(equalTo: photoSection.bottomAnchor),
            infoSection.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor),
            infoSection.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor),
            infoSection.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor),

            categoryContainer.topAnchor.constraint(equalTo: infoSection.topAnchor, constant: 14),
            categoryContainer.leadingAnchor.constraint(equalTo: infoSection.leadingAnchor, constant: 14),

            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor, constant: 5),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: -5),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor, constant: 11),
            categoryLabel.trailingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: -11),

            dateLabel.centerYAnchor.constraint(equalTo: categoryContainer.centerYAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: categoryContainer.trailingAnchor, constant: 8),

            titleLabel.topAnchor.constraint(equalTo: categoryContainer.bottomAnchor, constant: 6),
            titleLabel.leadingAnchor.constraint(equalTo: infoSection.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: infoSection.trailingAnchor, constant: -14),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: infoSection.leadingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: infoSection.trailingAnchor, constant: -14),
            subtitleLabel.bottomAnchor.constraint(equalTo: infoSection.bottomAnchor, constant: -16),
        ])
    }

    func configure(with first: First) {
        largePhotoView.backgroundColor = first.largePhotoColor
        smallPhotoView.backgroundColor = first.smallPhotoColor
        extraCountLabel.text = "+\(first.extraPhotos)"
        categoryLabel.text = first.category
        dateLabel.text = first.date
        titleLabel.text = first.title
        subtitleLabel.text = "\(first.location) · \(first.duration), \(first.photoCount) photos"
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
    let label: String
    let date: String
    let reason: String
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

// MARK: - ReviewQueueCell

class ReviewQueueCell: UITableViewCell {
    static let identifier = "ReviewQueueCell"

    private let card = UIView()
    private let accentBar = UIView()
    private let iconLabel = UILabel()
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
        card.layer.shadowOpacity = 0.07
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        contentView.addSubview(card)

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = UIColor(named: "ClayAccent")
        accentBar.layer.cornerRadius = 1.5
        card.addSubview(accentBar)

        iconLabel.translatesAutoresizingMaskIntoConstraints = false
        iconLabel.text = "!"
        iconLabel.font = .karla(.bold, size: 13)
        iconLabel.textColor = UIColor(named: "ClayAccent")
        iconLabel.textAlignment = .center
        iconLabel.backgroundColor = UIColor(named: "ClayAccent")?.withAlphaComponent(0.15)
        iconLabel.layer.cornerRadius = 12
        iconLabel.layer.masksToBounds = true
        card.addSubview(iconLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .fraunces(.bold, size: 18)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 1
        card.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .karla(.medium, size: 13)
        subtitleLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.52)
        subtitleLabel.numberOfLines = 1
        card.addSubview(subtitleLabel)

        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.image = UIImage(systemName: "chevron.right",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))
        chevron.tintColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.25)
        chevron.contentMode = .scaleAspectFit
        card.addSubview(chevron)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            accentBar.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            accentBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            iconLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            iconLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconLabel.widthAnchor.constraint(equalToConstant: 24),
            iconLabel.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.leadingAnchor.constraint(equalTo: iconLabel.trailingAnchor, constant: 10),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            subtitleLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),

            chevron.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
        ])
    }

    func configure(with item: ReviewItem) {
        titleLabel.text = item.label
        subtitleLabel.text = "\(item.date) · \(item.reason)"
    }
}
