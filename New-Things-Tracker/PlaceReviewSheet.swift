import UIKit
import SwiftData
import Photos

// The review carousel's "No" and card-tap both land here. Offers the full correction set from the
// algorithm spec: pick among the top-3 scored candidates (with an editable name), not-a-place,
// home/work/private, or merge into an existing Place. Never writes to the store directly — hands a
// CorrectionDraft to FirstsStore.applyCorrection, which enqueues a targeted re-resolve of just this
// Stay rather than a full pipeline run.
class PlaceReviewSheet: UIViewController {

    private let candidate: ReviewCandidate
    private let store: FirstsStore
    private var selectedCandidate: CandidateOption?

    private let thumbnailView = UIImageView()
    private var nameField: UITextField!
    private var otherMatchesButton: UIButton!

    init(candidate: ReviewCandidate, store: FirstsStore) {
        self.candidate = candidate
        self.store = store
        self.selectedCandidate = candidate.topCandidates.first
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        setupContent()
        loadThumbnail()
    }

    // MARK: - Layout

    private func setupContent() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),
        ])

        let titleLabel = UILabel()
        titleLabel.font = .fraunces(.bold, size: 22)
        titleLabel.textColor = UIColor(named: "FogBackground")
        titleLabel.text = "Was this your first time here?"
        titleLabel.numberOfLines = 0
        stack.addArrangedSubview(titleLabel)

        let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "EEE d MMM 'at' h:mm a"; return f }()
        let subtitleLabel = UILabel()
        subtitleLabel.font = .karla(.regular, size: 14)
        subtitleLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.6)
        subtitleLabel.text = "\(dateFmt.string(from: candidate.firstVisitDate)) · \(candidate.totalPhotoCount) photo\(candidate.totalPhotoCount == 1 ? "" : "s")"
        stack.addArrangedSubview(subtitleLabel)

        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 14
        thumbnailView.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.08)
        thumbnailView.heightAnchor.constraint(equalToConstant: 140).isActive = true
        stack.addArrangedSubview(thumbnailView)

        nameField = UITextField()
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.text = selectedCandidate?.displayName ?? ""
        nameField.placeholder = "Name this place"
        nameField.font = .karla(.semibold, size: 17)
        nameField.textColor = UIColor(named: "FogBackground")
        nameField.borderStyle = .roundedRect
        nameField.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.10)
        stack.addArrangedSubview(nameField)

        if candidate.topCandidates.count > 1 {
            otherMatchesButton = makeTextButton("See \(candidate.topCandidates.count - 1) other nearby match\(candidate.topCandidates.count - 1 == 1 ? "" : "es")…")
            otherMatchesButton.addTarget(self, action: #selector(pickOtherMatchTapped), for: .touchUpInside)
            stack.addArrangedSubview(otherMatchesButton)
        }

        stack.addArrangedSubview(makeFilledButton("Confirm", action: #selector(confirmTapped)))
        stack.addArrangedSubview(spacer(height: 8))
        stack.addArrangedSubview(makeOutlineButton("Not a place", action: #selector(notAPlaceTapped)))
        stack.addArrangedSubview(makeOutlineButton("This is my home", action: #selector(markHomeTapped)))
        stack.addArrangedSubview(makeOutlineButton("This is work", action: #selector(markWorkTapped)))
        stack.addArrangedSubview(makeOutlineButton("Keep private", action: #selector(markPrivateTapped)))
        stack.addArrangedSubview(makeOutlineButton("Merge into another place…", action: #selector(mergeTapped)))
    }

    private func spacer(height: CGFloat) -> UIView {
        let view = UIView()
        view.heightAnchor.constraint(equalToConstant: height).isActive = true
        return view
    }

    private func makeFilledButton(_ title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.baseBackgroundColor = UIColor(named: "ClayAccent")
        config.baseForegroundColor = UIColor(named: "DeepPineInk")
        config.cornerStyle = .medium
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming; outgoing.font = .karla(.semibold, size: 16); return outgoing
        }
        let button = UIButton(configuration: config)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeOutlineButton(_ title: String, action: Selector) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = UIColor(named: "FogBackground")
        config.background.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.08)
        config.background.cornerRadius = 12
        config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming; outgoing.font = .karla(.medium, size: 15); return outgoing
        }
        let button = UIButton(configuration: config)
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func makeTextButton(_ title: String) -> UIButton {
        var config = UIButton.Configuration.plain()
        config.title = title
        config.baseForegroundColor = UIColor(named: "ClayAccent")
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming; outgoing.font = .karla(.medium, size: 13); return outgoing
        }
        return UIButton(configuration: config)
    }

    // MARK: - Photo

    private func loadThumbnail() {
        guard let localID = candidate.photoLocalIDs.first else {
            thumbnailView.image = nil
            return
        }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localID], options: nil)
        guard let asset = assets.firstObject else { return }
        let opts = PHImageRequestOptions()
        opts.deliveryMode = .opportunistic
        opts.isNetworkAccessAllowed = true
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 600, height: 300), contentMode: .aspectFill, options: opts
        ) { [weak self] image, _ in
            DispatchQueue.main.async { self?.thumbnailView.image = image }
        }
    }

    // MARK: - Actions

    @objc private func pickOtherMatchTapped() {
        let alert = UIAlertController(title: "Which place?", message: nil, preferredStyle: .actionSheet)
        for option in candidate.topCandidates {
            alert.addAction(UIAlertAction(title: option.displayName, style: .default) { [weak self] _ in
                self?.selectedCandidate = option
                self?.nameField.text = option.displayName
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = otherMatchesButton
            popover.sourceRect = otherMatchesButton.bounds
        }
        present(alert, animated: true)
    }

    private func currentDraft() -> POICandidateDraft {
        let name = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        var draft = selectedCandidate?.asDraft ?? POICandidateDraft(
            displayName: name?.isEmpty == false ? name! : "Somewhere new", mapKitIdentifier: nil,
            categoryGroup: .unknown, poiCategoryRaw: nil,
            latitude: candidate.centroid.latitude, longitude: candidate.centroid.longitude
        )
        if let name, !name.isEmpty { draft.displayName = name }
        return draft
    }

    @objc private func confirmTapped() {
        apply(.selectCandidate(currentDraft()))
    }

    @objc private func notAPlaceTapped() {
        apply(.notAPlace)
    }

    // home/work/private all require a Place to exist on the Stay first, so confirm the current
    // selection before applying the role.
    @objc private func markHomeTapped() { applyRoleAction(.markHome) }
    @objc private func markWorkTapped() { applyRoleAction(.markWork) }
    @objc private func markPrivateTapped() { applyRoleAction(.markPrivate) }

    private func applyRoleAction(_ action: CorrectionAction) {
        Task {
            await store.applyCorrection(CorrectionDraft(stayID: candidate.id, action: .selectCandidate(currentDraft())))
            await store.applyCorrection(CorrectionDraft(stayID: candidate.id, action: action))
            await finish()
        }
    }

    @objc private func mergeTapped() {
        let nearby = store.nearbyPlaces(to: candidate.centroid, excludingKey: "")
        guard !nearby.isEmpty else {
            let alert = UIAlertController(title: "No nearby places", message: "There's nothing close enough to merge into yet.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let alert = UIAlertController(title: "Merge into…", message: nil, preferredStyle: .actionSheet)
        for place in nearby {
            alert.addAction(UIAlertAction(title: place.placeName, style: .default) { [weak self] _ in
                self?.performMerge(intoKey: place.key)
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }

    private func performMerge(intoKey targetKey: String) {
        Task {
            await store.applyCorrection(CorrectionDraft(stayID: candidate.id, action: .selectCandidate(currentDraft())))
            await store.applyCorrection(CorrectionDraft(stayID: candidate.id, action: .merge(intoPlaceKey: targetKey)))
            await finish()
        }
    }

    private func apply(_ action: CorrectionAction) {
        Task {
            await store.applyCorrection(CorrectionDraft(stayID: candidate.id, action: action))
            await finish()
        }
    }

    @MainActor
    private func finish() {
        dismiss(animated: true)
    }
}
