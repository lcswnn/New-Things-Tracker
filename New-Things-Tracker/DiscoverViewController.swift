import UIKit

class DiscoverViewController: UIViewController {

    private var titleLabel: UILabel!
    private var contextLabel: UILabel!
    private var searchContainer: UIView!
    private var contentView: UIView!
    private var trendingStack: UIStackView!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
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
        contextLabel.text = "Chicago, IL  ·  47 things you haven't tried"
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

        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            sectionLabel.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 30),
            sectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            scrollView.topAnchor.constraint(equalTo: sectionLabel.bottomAnchor, constant: 14),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 200),
        ])

        let placeholders: [(title: String, distance: String, color: UIColor)] = [
            ("Millennium Park",  "0.3 mi away", UIColor(red: 0.79, green: 0.87, blue: 0.82, alpha: 1)),
            ("Art Institute",    "0.6 mi away", UIColor(red: 0.88, green: 0.78, blue: 0.72, alpha: 1)),
            ("Navy Pier",        "1.2 mi away", UIColor(named: "ClayAccent")?.withAlphaComponent(0.5) ?? .orange),
            ("Riverwalk",        "0.5 mi away", UIColor(named: "DustySage")?.withAlphaComponent(0.65) ?? .gray),
            ("Lincoln Park Zoo", "2.1 mi away", UIColor(red: 0.82, green: 0.88, blue: 0.75, alpha: 1)),
        ]

        let cardW: CGFloat = 160, cardH: CGFloat = 190, gap: CGFloat = 12, lead: CGFloat = 20
        var x: CGFloat = lead
        for item in placeholders {
            let card = makeNearYouCard(title: item.title, distance: item.distance, color: item.color, width: cardW, height: cardH)
            card.frame = CGRect(x: x, y: 0, width: cardW, height: cardH)
            scrollView.addSubview(card)
            x += cardW + gap
        }
        scrollView.contentSize = CGSize(width: x - gap + lead, height: cardH)

        // Keep a reference so Trending can anchor below
        scrollView.tag = 100
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

    private func makeNearYouCard(title: String, distance: String, color: UIColor, width: CGFloat, height: CGFloat) -> UIView {
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
        card.addSubview(photoView)

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
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -110),
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
