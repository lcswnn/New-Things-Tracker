import UIKit

// A track with a colored fill sized as a fraction of its own width — used for the per-category
// and milestone progress bars, where the fill width depends on sibling data, not just autolayout.
private final class ProgressBarView: UIView {
    var fraction: CGFloat = 0 { didSet { setNeedsLayout() } }
    private let fillView = UIView()

    init(trackColor: UIColor, fillColor: UIColor?) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = trackColor
        clipsToBounds = true
        fillView.backgroundColor = fillColor
        addSubview(fillView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        fillView.layer.cornerRadius = bounds.height / 2
        fillView.frame = CGRect(x: 0, y: 0, width: bounds.width * max(0, min(1, fraction)), height: bounds.height)
    }
}

class StatsViewController: UIViewController {

    // Set by the parent view controller once its own environment is available (AppEnvironment
    // isn't guaranteed to exist yet when this VC's view loads).
    var environment: AppEnvironment!

    private var contentView: UIView!
    private var totalLabel: UILabel!

    private var monthBars: [UIView] = []
    private var monthBarHeights: [NSLayoutConstraint] = []

    private var categoryRows: [(container: UIView, name: UILabel, count: UILabel, bar: ProgressBarView)] = []
    private var categoryCountBadge: UILabel!

    private var milestoneTitleLabel: UILabel!
    private var milestoneBar: ProgressBarView!
    private var milestoneCaptionLabel: UILabel!

    private static let monthAbbrev = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

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
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Your year in firsts"
        titleLabel.font = .frauncesBoldItalic(size: 28)
        titleLabel.textColor = UIColor(named: "FogBackground")
        contentView.addSubview(titleLabel)

        let totalsCard = makeTotalsCard()
        contentView.addSubview(totalsCard)

        let categoriesCard = makeCategoriesCard()
        contentView.addSubview(categoriesCard)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            totalsCard.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            totalsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            totalsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            categoriesCard.topAnchor.constraint(equalTo: totalsCard.bottomAnchor, constant: 16),
            categoriesCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            categoriesCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            categoriesCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
        ])
    }

    // MARK: - Totals card (hero number + per-month bar chart)

    private func makeTotalsCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 22
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 10

        totalLabel = UILabel()
        totalLabel.translatesAutoresizingMaskIntoConstraints = false
        totalLabel.text = "0"
        totalLabel.font = .fraunces(.bold, size: 60)
        totalLabel.textColor = UIColor(named: "ClayAccent")
        totalLabel.textAlignment = .center
        card.addSubview(totalLabel)

        let captionLabel = UILabel()
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.text = "firsts all time"
        captionLabel.font = .karla(.regular, size: 14)
        captionLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.50)
        captionLabel.textAlignment = .center
        card.addSubview(captionLabel)

        let chartHeader = UILabel()
        chartHeader.translatesAutoresizingMaskIntoConstraints = false
        chartHeader.text = "Firsts per month"
        chartHeader.font = .fraunces(.bold, size: 17)
        chartHeader.textColor = UIColor(named: "DeepPineInk")
        card.addSubview(chartHeader)

        let barsRow = UIStackView()
        barsRow.translatesAutoresizingMaskIntoConstraints = false
        barsRow.axis = .horizontal
        barsRow.alignment = .bottom
        barsRow.distribution = .fillEqually
        barsRow.spacing = 6
        card.addSubview(barsRow)

        let labelsRow = UIStackView()
        labelsRow.translatesAutoresizingMaskIntoConstraints = false
        labelsRow.axis = .horizontal
        labelsRow.distribution = .fillEqually
        labelsRow.spacing = 6
        card.addSubview(labelsRow)

        for month in Self.monthAbbrev {
            let bar = UIView()
            bar.translatesAutoresizingMaskIntoConstraints = false
            bar.backgroundColor = UIColor(named: "DustySage")?.withAlphaComponent(0.45)
            bar.layer.cornerRadius = 5
            let heightConstraint = bar.heightAnchor.constraint(equalToConstant: 6)
            heightConstraint.isActive = true
            monthBars.append(bar)
            monthBarHeights.append(heightConstraint)

            let barWrapper = UIView()
            barWrapper.translatesAutoresizingMaskIntoConstraints = false
            barWrapper.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: barWrapper.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: barWrapper.trailingAnchor),
                bar.bottomAnchor.constraint(equalTo: barWrapper.bottomAnchor),
            ])
            barsRow.addArrangedSubview(barWrapper)

            let label = UILabel()
            label.text = month
            label.font = .karla(.medium, size: 10)
            label.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.45)
            label.textAlignment = .center
            labelsRow.addArrangedSubview(label)
        }

        NSLayoutConstraint.activate([
            totalLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            totalLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            captionLabel.topAnchor.constraint(equalTo: totalLabel.bottomAnchor, constant: 0),
            captionLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            chartHeader.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 26),
            chartHeader.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            barsRow.topAnchor.constraint(equalTo: chartHeader.bottomAnchor, constant: 18),
            barsRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            barsRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            barsRow.heightAnchor.constraint(equalToConstant: 64),

            labelsRow.topAnchor.constraint(equalTo: barsRow.bottomAnchor, constant: 6),
            labelsRow.leadingAnchor.constraint(equalTo: barsRow.leadingAnchor),
            labelsRow.trailingAnchor.constraint(equalTo: barsRow.trailingAnchor),
            labelsRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        return card
    }

    // MARK: - Categories card (top categories + milestone banner)

    private func makeCategoriesCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "FogBackground")
        card.layer.cornerRadius = 22
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 10

        let headerLabel = UILabel()
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerLabel.text = "Top categories"
        headerLabel.font = .fraunces(.bold, size: 20)
        headerLabel.textColor = UIColor(named: "DeepPineInk")
        card.addSubview(headerLabel)

        let badge = UIView()
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.backgroundColor = UIColor(named: "ClayAccent")
        badge.layer.cornerRadius = 14
        card.addSubview(badge)

        categoryCountBadge = UILabel()
        categoryCountBadge.translatesAutoresizingMaskIntoConstraints = false
        categoryCountBadge.font = .karla(.bold, size: 14)
        categoryCountBadge.textColor = .white
        categoryCountBadge.textAlignment = .center
        badge.addSubview(categoryCountBadge)

        let rowsStack = UIStackView()
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        rowsStack.axis = .vertical
        rowsStack.spacing = 16
        card.addSubview(rowsStack)

        for _ in 0..<3 {
            rowsStack.addArrangedSubview(makeCategoryRow())
        }

        let milestoneCard = makeMilestoneBanner()
        card.addSubview(milestoneCard)

        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            headerLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            badge.centerYAnchor.constraint(equalTo: headerLabel.centerYAnchor),
            badge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            badge.widthAnchor.constraint(equalToConstant: 28),
            badge.heightAnchor.constraint(equalToConstant: 28),

            categoryCountBadge.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            categoryCountBadge.centerYAnchor.constraint(equalTo: badge.centerYAnchor),

            rowsStack.topAnchor.constraint(equalTo: headerLabel.bottomAnchor, constant: 20),
            rowsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            rowsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            milestoneCard.topAnchor.constraint(equalTo: rowsStack.bottomAnchor, constant: 22),
            milestoneCard.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            milestoneCard.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            milestoneCard.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    private func makeCategoryRow() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = UILabel()
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .karla(.semibold, size: 15)
        nameLabel.textColor = UIColor(named: "DeepPineInk")
        container.addSubview(nameLabel)

        let countLabel = UILabel()
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .fraunces(.bold, size: 16)
        countLabel.textColor = UIColor(named: "DeepPineInk")
        container.addSubview(countLabel)

        let bar = ProgressBarView(
            trackColor: UIColor(named: "DustySage")?.withAlphaComponent(0.25) ?? .lightGray,
            fillColor: UIColor(named: "ClayAccent")
        )
        container.addSubview(bar)

        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: container.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            countLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            countLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: nameLabel.trailingAnchor, constant: 8),

            bar.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: 7),
            bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        categoryRows.append((container, nameLabel, countLabel, bar))
        return container
    }

    private func makeMilestoneBanner() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = UIColor(named: "ClayAccent")?.withAlphaComponent(0.16)
        card.layer.cornerRadius = 16

        let flagIcon = UIImageView(image: UIImage(systemName: "flag.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        flagIcon.translatesAutoresizingMaskIntoConstraints = false
        flagIcon.tintColor = UIColor(named: "ClayAccent")
        flagIcon.contentMode = .scaleAspectFit
        card.addSubview(flagIcon)

        milestoneTitleLabel = UILabel()
        milestoneTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        milestoneTitleLabel.font = .karla(.bold, size: 15)
        milestoneTitleLabel.textColor = UIColor(named: "DeepPineInk")
        milestoneTitleLabel.numberOfLines = 2
        card.addSubview(milestoneTitleLabel)

        milestoneBar = ProgressBarView(
            trackColor: UIColor(named: "FogBackground")?.withAlphaComponent(0.55) ?? .white,
            fillColor: UIColor(named: "ClayAccent")
        )
        card.addSubview(milestoneBar)

        milestoneCaptionLabel = UILabel()
        milestoneCaptionLabel.translatesAutoresizingMaskIntoConstraints = false
        milestoneCaptionLabel.font = .karla(.regular, size: 12)
        milestoneCaptionLabel.textColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.55)
        card.addSubview(milestoneCaptionLabel)

        NSLayoutConstraint.activate([
            flagIcon.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            flagIcon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            flagIcon.widthAnchor.constraint(equalToConstant: 18),

            milestoneTitleLabel.centerYAnchor.constraint(equalTo: flagIcon.centerYAnchor),
            milestoneTitleLabel.leadingAnchor.constraint(equalTo: flagIcon.trailingAnchor, constant: 10),
            milestoneTitleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            milestoneBar.topAnchor.constraint(equalTo: milestoneTitleLabel.bottomAnchor, constant: 12),
            milestoneBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            milestoneBar.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            milestoneBar.heightAnchor.constraint(equalToConstant: 8),

            milestoneCaptionLabel.topAnchor.constraint(equalTo: milestoneBar.bottomAnchor, constant: 8),
            milestoneCaptionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            milestoneCaptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            milestoneCaptionLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])

        return card
    }

    // MARK: - Data refresh

    // Called by the parent view controller whenever the store's places change or the Stats tab
    // becomes active — recomputes every real number on screen from `environment.store`.
    func refresh() {
        guard let environment else { return }
        let places = environment.store.places
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let currentMonth = calendar.component(.month, from: Date())

        totalLabel.text = "\(places.count)"

        var monthCounts = [Int](repeating: 0, count: 12)
        for place in places {
            let comps = calendar.dateComponents([.year, .month], from: place.firstVisitDate)
            guard comps.year == currentYear, let month = comps.month else { continue }
            monthCounts[month - 1] += 1
        }
        let maxMonthCount = max(monthCounts.max() ?? 0, 1)
        for (index, count) in monthCounts.enumerated() {
            monthBarHeights[index].constant = max(6, 64 * CGFloat(count) / CGFloat(maxMonthCount))
            monthBars[index].backgroundColor = (index + 1 == currentMonth)
                ? UIColor(named: "ClayAccent")
                : UIColor(named: "DustySage")?.withAlphaComponent(0.45)
        }

        var categoryCounts: [PlaceCategoryGroup: Int] = [:]
        for place in places {
            guard let group = environment.store.place(for: place.id)?.categoryGroup, group != .unknown else { continue }
            categoryCounts[group, default: 0] += 1
        }
        let topCategories = categoryCounts.sorted { $0.value > $1.value }.prefix(categoryRows.count)
        categoryCountBadge.text = "\(topCategories.count)"
        let topMaxCount = max(topCategories.first?.value ?? 1, 1)
        for (index, row) in categoryRows.enumerated() {
            guard index < topCategories.count else { row.container.isHidden = true; continue }
            let entry = topCategories[topCategories.index(topCategories.startIndex, offsetBy: index)]
            row.container.isHidden = false
            row.name.text = displayName(for: entry.key)
            row.count.text = "\(entry.value)"
            row.bar.fraction = CGFloat(entry.value) / CGFloat(topMaxCount)
        }

        let nextMilestone = places.isEmpty ? 50 : places.count - (places.count % 50) + 50
        let progress = CGFloat(places.count) / CGFloat(nextMilestone)
        milestoneTitleLabel.text = "\(nextMilestone - places.count) to go until \(nextMilestone) firsts"
        milestoneBar.fraction = progress

        let percent = Int((progress * 100).rounded())
        if places.count > 1, let oldestDate = places.map(\.firstVisitDate).min() {
            let monthsSinceStart = max(1, calendar.dateComponents([.month], from: oldestDate, to: Date()).month ?? 1)
            let pace = max(1, Int((Double(monthsSinceStart) / Double(places.count)).rounded()))
            milestoneCaptionLabel.text = "\(percent)% to \(nextMilestone) · \(pace) month\(pace == 1 ? "" : "s") average pace"
        } else {
            milestoneCaptionLabel.text = "\(percent)% to \(nextMilestone)"
        }

        view.layoutIfNeeded()
    }

    private func displayName(for group: PlaceCategoryGroup) -> String {
        switch group {
        case .unknown:      return "Other"
        case .outdoors:     return "Outdoors"
        case .culture:      return "Culture"
        case .foodAndDrink: return "Food & Drink"
        case .lodging:      return "Lodging"
        case .retail:       return "Retail"
        case .transit:      return "Transit"
        case .services:     return "Services"
        case .fitness:      return "Fitness"
        case .education:    return "Education"
        case .nightlife:    return "Nightlife"
        case .utility:      return "Utility"
        }
    }
}
