import UIKit

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
        largePhotoLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
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
        smallPhotoLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        smallPhotoLabel.textColor = UIColor.black.withAlphaComponent(0.25)
        smallPhotoLabel.textAlignment = .center
        smallPhotoView.addSubview(smallPhotoLabel)

        extraCountContainer.translatesAutoresizingMaskIntoConstraints = false
        extraCountContainer.backgroundColor = UIColor.black.withAlphaComponent(0.06)
        rightColumn.addSubview(extraCountContainer)

        extraCountLabel.translatesAutoresizingMaskIntoConstraints = false
        extraCountLabel.font = UIFont.systemFont(ofSize: 17, weight: .medium)
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
        categoryLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        categoryLabel.textColor = UIColor(named: "DeepPineInk")
        categoryContainer.addSubview(categoryLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        dateLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.55)
        infoSection.addSubview(dateLabel)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = UIColor(named: "DeepPineInk")
        titleLabel.numberOfLines = 2
        infoSection.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
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
