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

    // Actual photo thumbnails layered on top of the color placeholders
    private let largeImageView = UIImageView()
    private let smallImageView = UIImageView()
    private var largeRequestID: PHImageRequestID?
    private var smallRequestID: PHImageRequestID?

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

        largeImageView.translatesAutoresizingMaskIntoConstraints = false
        largeImageView.contentMode = .scaleAspectFill
        largeImageView.clipsToBounds = true
        largePhotoView.addSubview(largeImageView)

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

        smallImageView.translatesAutoresizingMaskIntoConstraints = false
        smallImageView.contentMode = .scaleAspectFill
        smallImageView.clipsToBounds = true
        smallPhotoView.addSubview(smallImageView)

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

            largeImageView.topAnchor.constraint(equalTo: largePhotoView.topAnchor),
            largeImageView.bottomAnchor.constraint(equalTo: largePhotoView.bottomAnchor),
            largeImageView.leadingAnchor.constraint(equalTo: largePhotoView.leadingAnchor),
            largeImageView.trailingAnchor.constraint(equalTo: largePhotoView.trailingAnchor),

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

            smallImageView.topAnchor.constraint(equalTo: smallPhotoView.topAnchor),
            smallImageView.bottomAnchor.constraint(equalTo: smallPhotoView.bottomAnchor),
            smallImageView.leadingAnchor.constraint(equalTo: smallPhotoView.leadingAnchor),
            smallImageView.trailingAnchor.constraint(equalTo: smallPhotoView.trailingAnchor),

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

    override func prepareForReuse() {
        super.prepareForReuse()
        cancelImageRequests()
        largeImageView.image = nil
        smallImageView.image  = nil
    }

    func configure(with first: FirstCardViewModel) {
        cancelImageRequests()
        largeImageView.image = nil
        smallImageView.image  = nil

        largePhotoView.backgroundColor = first.largePhotoColor
        smallPhotoView.backgroundColor = first.smallPhotoColor

        let ids = first.photoLocalIDs
        largePhotoLabel.isHidden = !ids.isEmpty
        smallPhotoLabel.isHidden = ids.count > 1

        if ids.count > 0 { largeRequestID = loadPhoto(ids[0], into: largeImageView, pointSize: CGSize(width: 400, height: 220)) }
        if ids.count > 1 { smallRequestID = loadPhoto(ids[1], into: smallImageView, pointSize: CGSize(width: 200, height: 100)) }

        extraCountContainer.isHidden = first.extraPhotos == 0
        extraCountLabel.text = "+\(first.extraPhotos)"
        categoryLabel.text = first.category
        dateLabel.text = first.date
        titleLabel.text = first.title
        if first.photoCount > 0 {
            subtitleLabel.text = "\(first.location) · \(first.duration), \(first.photoCount) photos"
        } else {
            subtitleLabel.text = "\(first.location) · \(first.duration)"
        }
    }

    private func cancelImageRequests() {
        if let id = largeRequestID { PHImageManager.default().cancelImageRequest(id); largeRequestID = nil }
        if let id = smallRequestID { PHImageManager.default().cancelImageRequest(id); smallRequestID = nil }
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
        titleLabel.text = first.title
        subtitleLabel.text = "\(first.date) · \(first.location)"
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

// MARK: - ReviewCardCell

protocol ReviewCardCellDelegate: AnyObject {
    func reviewCardCell(_ cell: ReviewCardCell, didAnswerYesFor id: PersistentIdentifier)
    func reviewCardCell(_ cell: ReviewCardCell, didAnswerNoFor id: PersistentIdentifier)
    func reviewCardCell(_ cell: ReviewCardCell, didTapCardFor id: PersistentIdentifier)
}

// Single table row holding a horizontally-paged stack of ReviewPageCells, one per place needing input,
// with a page control along the bottom instead of separate rows.
class ReviewCardCell: UITableViewCell {
    static let identifier = "ReviewCardCell"

    weak var delegate: ReviewCardCellDelegate?

    private let card = UIView()
    private let collectionView: UICollectionView
    private let pageControl = UIPageControl()
    private var items: [ReviewItem] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .clear
        contentView.addSubview(card)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .clear
        collectionView.isPagingEnabled = true
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ReviewPageCell.self, forCellWithReuseIdentifier: ReviewPageCell.identifier)
        card.addSubview(collectionView)

        pageControl.translatesAutoresizingMaskIntoConstraints = false
        // Custom dot images with a white outline so the dots stay visible against any background.
        pageControl.preferredIndicatorImage = makeDotImage(fillColor: (UIColor(named: "DeepPineInk") ?? .black).withAlphaComponent(0.35))
        pageControl.preferredCurrentPageIndicatorImage = makeDotImage(fillColor: UIColor(named: "ClayAccent") ?? .orange)
        pageControl.hidesForSinglePage = true
        pageControl.isUserInteractionEnabled = false
        card.addSubview(pageControl)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            collectionView.topAnchor.constraint(equalTo: card.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            collectionView.heightAnchor.constraint(equalToConstant: 132),

            pageControl.topAnchor.constraint(equalTo: collectionView.bottomAnchor, constant: 6),
            pageControl.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            pageControl.bottomAnchor.constraint(equalTo: card.bottomAnchor),
        ])
    }

    private func makeDotImage(fillColor: UIColor, diameter: CGFloat = 7, borderWidth: CGFloat = 1.3) -> UIImage {
        let size = CGSize(width: diameter + borderWidth * 2, height: diameter + borderWidth * 2)
        return UIGraphicsImageRenderer(size: size).image { _ in
            let rect = CGRect(x: borderWidth, y: borderWidth, width: diameter, height: diameter)
            let path = UIBezierPath(ovalIn: rect)
            fillColor.setFill()
            path.fill()
            UIColor.white.setStroke()
            path.lineWidth = borderWidth
            path.stroke()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout,
              collectionView.bounds.width > 0,
              layout.itemSize != collectionView.bounds.size else { return }
        layout.itemSize = collectionView.bounds.size
        layout.invalidateLayout()
    }

    // items.count is expected to only ever shrink by one between calls (an answered candidate leaving
    // the queue), so keeping the same page index naturally reveals the next place needing input.
    func configure(with items: [ReviewItem], delegate: ReviewCardCellDelegate?) {
        self.items = items
        self.delegate = delegate
        collectionView.isUserInteractionEnabled = true
        pageControl.numberOfPages = items.count
        let clampedPage = min(pageControl.currentPage, max(items.count - 1, 0))
        pageControl.currentPage = clampedPage
        collectionView.reloadData()
        collectionView.layoutIfNeeded()
        guard !items.isEmpty else { return }
        collectionView.scrollToItem(at: IndexPath(item: clampedPage, section: 0), at: .centeredHorizontally, animated: false)
    }

    // Shrinks and fades the answered card into the background, then swipes the carousel to the next
    // page (if there is one) before handing off to the delegate, so answering Yes/No visibly settles
    // the current card and advances to the next place instead of just popping out.
    private func answerAndAdvance(from index: Int, completion: @escaping () -> Void) {
        collectionView.isUserInteractionEnabled = false
        let answeredCell = collectionView.cellForItem(at: IndexPath(item: index, section: 0)) as? ReviewPageCell

        let advance = { [weak self] in
            guard let self else { completion(); return }
            let nextIndex = index + 1
            guard nextIndex < self.items.count, self.collectionView.bounds.width > 0 else {
                completion()
                return
            }
            self.pageControl.currentPage = nextIndex
            UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseInOut], animations: {
                self.collectionView.scrollToItem(at: IndexPath(item: nextIndex, section: 0), at: .centeredHorizontally, animated: false)
            }, completion: { _ in
                self.pageControl.currentPage = index
                completion()
            })
        }

        if let answeredCell {
            answeredCell.playAnsweredAnimation(completion: advance)
        } else {
            advance()
        }
    }
}

extension ReviewCardCell: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ReviewPageCell.identifier, for: indexPath) as! ReviewPageCell
        // Capture the item's stable id (not indexPath.item) so a delegate callback that fires after
        // `items` has already been mutated by a later `configure(with:)` still resolves to the right place.
        let item = items[indexPath.item]
        cell.configure(with: item)
        cell.onYes = { [weak self] in
            guard let self else { return }
            self.answerAndAdvance(from: indexPath.item) {
                self.delegate?.reviewCardCell(self, didAnswerYesFor: item.id)
            }
        }
        cell.onNo = { [weak self] in
            guard let self else { return }
            self.answerAndAdvance(from: indexPath.item) {
                self.delegate?.reviewCardCell(self, didAnswerNoFor: item.id)
            }
        }
        cell.onTapCard = { [weak self] in
            guard let self else { return }
            self.delegate?.reviewCardCell(self, didTapCardFor: item.id)
        }
        return cell
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView.bounds.width > 0, !items.isEmpty else { return }
        let page = Int(round(scrollView.contentOffset.x / scrollView.bounds.width))
        pageControl.currentPage = max(0, min(page, items.count - 1))
    }
}

// MARK: - ReviewPageCell

// One page of the ReviewCardCell carousel — a photo of the place, its name, when it was visited, and Yes/No buttons.
class ReviewPageCell: UICollectionViewCell {
    static let identifier = "ReviewPageCell"

    var onYes: (() -> Void)?
    var onNo: (() -> Void)?
    var onTapCard: (() -> Void)?

    private let card = UIView()
    private let thumbnailView = UIView()
    private let thumbnailImageView = UIImageView()
    private let placeholderIcon = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let noButton = UIButton(type: .system)
    private let yesButton = UIButton(type: .system)
    private var imageRequestID: PHImageRequestID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear

        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8
        contentView.addSubview(card)

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.08)
        thumbnailView.layer.cornerRadius = 12
        thumbnailView.clipsToBounds = true
        card.addSubview(thumbnailView)

        placeholderIcon.translatesAutoresizingMaskIntoConstraints = false
        placeholderIcon.image = UIImage(systemName: "photo",
                                        withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium))
        placeholderIcon.tintColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.25)
        placeholderIcon.contentMode = .scaleAspectFit
        thumbnailView.addSubview(placeholderIcon)

        thumbnailImageView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailView.addSubview(thumbnailImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .fraunces(.bold, size: 19)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 1
        card.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .karla(.regular, size: 13)
        subtitleLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.52)
        subtitleLabel.numberOfLines = 1
        card.addSubview(subtitleLabel)

        configureButton(noButton, title: "No", filled: false)
        noButton.translatesAutoresizingMaskIntoConstraints = false
        noButton.addTarget(self, action: #selector(noTapped), for: .touchUpInside)
        card.addSubview(noButton)

        configureButton(yesButton, title: "Yes", filled: true)
        yesButton.translatesAutoresizingMaskIntoConstraints = false
        yesButton.addTarget(self, action: #selector(yesTapped), for: .touchUpInside)
        card.addSubview(yesButton)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(cardTapped))
        tapGesture.delegate = self
        card.isUserInteractionEnabled = true
        card.addGestureRecognizer(tapGesture)

        NSLayoutConstraint.activate([
            // Inset from the collection-view cell edges so adjacent cards don't visually touch while swiping.
            card.topAnchor.constraint(equalTo: contentView.topAnchor),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 6),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -6),

            thumbnailView.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            thumbnailView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            thumbnailView.widthAnchor.constraint(equalToConstant: 52),
            thumbnailView.heightAnchor.constraint(equalToConstant: 52),

            placeholderIcon.centerXAnchor.constraint(equalTo: thumbnailView.centerXAnchor),
            placeholderIcon.centerYAnchor.constraint(equalTo: thumbnailView.centerYAnchor),

            thumbnailImageView.topAnchor.constraint(equalTo: thumbnailView.topAnchor),
            thumbnailImageView.bottomAnchor.constraint(equalTo: thumbnailView.bottomAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: thumbnailView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: thumbnailView.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: thumbnailView.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            noButton.topAnchor.constraint(equalTo: thumbnailView.bottomAnchor, constant: 16),
            noButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            noButton.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            noButton.trailingAnchor.constraint(equalTo: card.centerXAnchor, constant: -6),
            noButton.heightAnchor.constraint(equalToConstant: 36),

            yesButton.topAnchor.constraint(equalTo: noButton.topAnchor),
            yesButton.bottomAnchor.constraint(equalTo: noButton.bottomAnchor),
            yesButton.leadingAnchor.constraint(equalTo: card.centerXAnchor, constant: 6),
            yesButton.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
    }

    private func configureButton(_ button: UIButton, title: String, filled: Bool) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .karla(.semibold, size: 15)
        button.layer.cornerRadius = 18
        if filled {
            button.backgroundColor = UIColor(named: "DeepPineInk")
            button.setTitleColor(UIColor(named: "FogBackground"), for: .normal)
        } else {
            button.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.08)
            button.setTitleColor(UIColor(named: "DeepPineInk"), for: .normal)
        }
    }

    @objc private func yesTapped() { onYes?() }
    @objc private func noTapped() { onNo?() }
    @objc private func cardTapped() { onTapCard?() }

    // Shrinks and fades this card back before the carousel advances, so answering reads as "this
    // card recedes" rather than an abrupt cut to the next page.
    func playAnsweredAnimation(completion: @escaping () -> Void) {
        isUserInteractionEnabled = false
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn], animations: {
            self.card.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
            self.card.alpha = 0
        }, completion: { _ in
            completion()
        })
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let id = imageRequestID { PHImageManager.default().cancelImageRequest(id); imageRequestID = nil }
        thumbnailImageView.image = nil
        placeholderIcon.isHidden = false
        card.transform = .identity
        card.alpha = 1
        isUserInteractionEnabled = true
    }

    func configure(with item: ReviewItem) {
        titleLabel.text = item.label
        subtitleLabel.text = "\(item.date) · \(item.reason)"

        thumbnailImageView.image = nil
        placeholderIcon.isHidden = !item.photoLocalIDs.isEmpty
        if let localID = item.photoLocalIDs.first {
            imageRequestID = loadThumbnail(localID, pointSize: CGSize(width: 52, height: 52))
        }
    }

    @discardableResult
    private func loadThumbnail(_ localID: String, pointSize: CGSize) -> PHImageRequestID? {
        let scale     = traitCollection.displayScale
        let pixelSize = CGSize(width: pointSize.width * scale, height: pointSize.height * scale)
        let assets    = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        guard let asset = assets.firstObject else { return nil }
        let opts = PHImageRequestOptions()
        opts.deliveryMode           = .opportunistic
        opts.isNetworkAccessAllowed = true
        opts.resizeMode             = .fast
        return PHImageManager.default().requestImage(
            for: asset, targetSize: pixelSize, contentMode: .aspectFill, options: opts
        ) { [weak self] image, _ in
            DispatchQueue.main.async { self?.thumbnailImageView.image = image }
        }
    }
}

extension ReviewPageCell: UIGestureRecognizerDelegate {
    // Let taps over the Yes/No buttons hit those controls instead of the card's tap gesture.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let point = touch.location(in: card)
        return !noButton.frame.contains(point) && !yesButton.frame.contains(point)
    }
}
