import UIKit

class StatsViewController: UIViewController {

    private var contentView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        setupScrollLayout()
        setupContent()
    }

    // MARK: - Scroll shell

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

    // MARK: - Content

    private func setupContent() {
        // Header
        let titleLabel  = lbl("Stats", font: .fraunces(.bold, size: 26), named: "FogBackground")
        let subtitleLabel = lbl("September 2026", font: .karla(.regular, size: 14), named: "FogBackground", alpha: 0.65)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)

        // Hero number
        let bigNumber = lbl("47", font: .fraunces(.bold, size: 86), named: "FogBackground")
        bigNumber.textAlignment = .center
        let bigSub = lbl("firsts logged", font: .karla(.regular, size: 15), named: "FogBackground", alpha: 0.50)
        bigSub.textAlignment = .center
        let quickStats = lbl("12 this year  ·  5 this month  ·  3 this week",
                              font: .karla(.medium, size: 13), named: "FogBackground", alpha: 0.45)
        quickStats.textAlignment = .center
        contentView.addSubview(bigNumber)
        contentView.addSubview(bigSub)
        contentView.addSubview(quickStats)

        // Card stack
        let mainStack = UIStackView()
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 12
        contentView.addSubview(mainStack)

        // Row 1: Time + Places
        mainStack.addArrangedSubview(makeRow([
            makeStatCard(icon: "clock.fill",
                         color: UIColor(named: "ClayAccent") ?? .orange,
                         value: "127 hrs",  label: "Time Outside"),
            makeStatCard(icon: "mappin.circle.fill",
                         color: UIColor(red: 0.40, green: 0.66, blue: 0.54, alpha: 1),
                         value: "34 spots", label: "Places Visited"),
        ]))

        // Row 2: Photos + Longest
        mainStack.addArrangedSubview(makeRow([
            makeStatCard(icon: "camera.fill",
                         color: UIColor(red: 0.54, green: 0.47, blue: 0.80, alpha: 1),
                         value: "892",      label: "Photos Taken"),
            makeStatCard(icon: "timer",
                         color: UIColor(red: 0.80, green: 0.60, blue: 0.40, alpha: 1),
                         value: "4h 32m",  label: "Longest First"),
        ]))

        // Full-width dark category card
        mainStack.addArrangedSubview(makeCategoryCard())

        // Row 3: Month + Streak
        let thirdRow = makeRow([
            makeStatCard(icon: "calendar",
                         color: UIColor(red: 0.40, green: 0.60, blue: 0.80, alpha: 1),
                         value: "August",   label: "Best Month"),
            makeStatCard(icon: "flame.fill",
                         color: UIColor(named: "ClayAccent") ?? .orange,
                         value: "8 days",  label: "Best Streak"),
        ])
        mainStack.addArrangedSubview(thirdRow)
        mainStack.setCustomSpacing(28, after: thirdRow)

        // Fun Facts header
        mainStack.addArrangedSubview(lbl("Fun Facts", font: .fraunces(.bold, size: 20), named: "FogBackground"))

        mainStack.addArrangedSubview(makeFunFactCard(
            emoji: "🌅", stat: "6:14 AM",
            detail: "earliest start time  ·  Sunrise Run on the 606 Trail"))
        mainStack.addArrangedSubview(makeFunFactCard(
            emoji: "✈️", stat: "847 mi",
            detail: "farthest from home  ·  Napa Valley, CA"))
        mainStack.addArrangedSubview(makeFunFactCard(
            emoji: "📸", stat: "47 photos",
            detail: "most in one trip  ·  Randolph Street Market"))

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            bigNumber.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 18),
            bigNumber.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            bigSub.topAnchor.constraint(equalTo: bigNumber.bottomAnchor, constant: 0),
            bigSub.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            quickStats.topAnchor.constraint(equalTo: bigSub.bottomAnchor, constant: 10),
            quickStats.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            quickStats.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            mainStack.topAnchor.constraint(equalTo: quickStats.bottomAnchor, constant: 28),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Card builders

    private func makeRow(_ cards: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: cards)
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 12
        return row
    }

    private func makeStatCard(icon: String, color: UIColor, value: String, label labelText: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        card.addSubview(iconView)

        let valueLabel = lbl(value, font: .fraunces(.bold, size: 26), named: "DeepPineInk")
        let nameLabel  = lbl(labelText, font: .karla(.regular, size: 12), named: "DeepPineInk", alpha: 0.50)
        card.addSubview(valueLabel)
        card.addSubview(nameLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            valueLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            valueLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),

            nameLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            nameLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 3),
            nameLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            nameLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
        ])

        return card
    }

    private func makeCategoryCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "DeepPineInk")
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.18
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 10

        let headerLabel  = lbl("Most Popular Category", font: .karla(.regular, size: 12), named: "FogBackground", alpha: 0.48)
        let catLabel     = lbl("Adventure", font: .fraunces(.bold, size: 34), named: "FogBackground")
        let countLabel   = lbl("12 firsts", font: .karla(.regular, size: 13), named: "FogBackground", alpha: 0.52)
        [headerLabel, catLabel, countLabel].forEach { card.addSubview($0) }

        let pillRow = UIStackView()
        pillRow.translatesAutoresizingMaskIntoConstraints = false
        pillRow.axis = .horizontal
        pillRow.spacing = 8
        pillRow.alignment = .center
        card.addSubview(pillRow)

        for (name, count) in [("Adventure", 12), ("Food", 9), ("Culture", 8), ("Music", 7)] {
            pillRow.addArrangedSubview(makePill("\(name) \(count)"))
        }

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            headerLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            catLabel.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 4),
            catLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            countLabel.topAnchor.constraint(equalTo: catLabel.bottomAnchor, constant: 2),
            countLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            pillRow.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 16),
            pillRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            pillRow.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -18),
            pillRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])

        return card
    }

    private func makePill(_ text: String) -> UIView {
        let pill = UIView()
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.12)
        pill.layer.cornerRadius = 11

        let label = lbl(text, font: .karla(.medium, size: 12), named: "FogBackground", alpha: 0.78)
        pill.addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 5),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -5),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -10),
        ])

        return pill
    }

    private func makeFunFactCard(emoji: String, stat: String, detail: String) -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 5

        let emojiLabel = UILabel()
        emojiLabel.translatesAutoresizingMaskIntoConstraints = false
        emojiLabel.text = emoji
        emojiLabel.font = .systemFont(ofSize: 28)
        card.addSubview(emojiLabel)

        let statLabel   = lbl(stat,   font: .fraunces(.bold, size: 19), named: "DeepPineInk")
        let detailLabel = lbl(detail, font: .karla(.regular, size: 12), named: "DeepPineInk", alpha: 0.50)
        detailLabel.numberOfLines = 2
        card.addSubview(statLabel)
        card.addSubview(detailLabel)

        NSLayoutConstraint.activate([
            emojiLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            emojiLabel.centerYAnchor.constraint(equalTo: card.centerYAnchor),

            statLabel.leadingAnchor.constraint(equalTo: emojiLabel.trailingAnchor, constant: 14),
            statLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            statLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            detailLabel.leadingAnchor.constraint(equalTo: statLabel.leadingAnchor),
            detailLabel.topAnchor.constraint(equalTo: statLabel.bottomAnchor, constant: 2),
            detailLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            detailLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])

        return card
    }

    // MARK: - Helpers

    private func lbl(_ text: String, font: UIFont, named colorName: String, alpha: CGFloat = 1.0) -> UILabel {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.text = text
        l.font = font
        l.textColor = UIColor(named: colorName)?.withAlphaComponent(alpha)
        return l
    }
}
