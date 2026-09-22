import UIKit
import Photos
import SwiftData

class PlaceDetailViewController: UIViewController {

    private let placeID: PersistentIdentifier
    private let store: FirstsStore
    private var summary: PlaceSummary!
    private var collectionView: UICollectionView!
    private var photoAssets: [PHAsset] = []

    init(placeID: PersistentIdentifier, store: FirstsStore) {
        self.placeID = placeID
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(named: "DustySage")
        guard let place = store.place(for: placeID) else { return }
        summary = PlaceSummary(place: place)
        setupCollectionView()
        loadAssets()
    }

    // MARK: - Collection view

    private func setupCollectionView() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1/3),
                heightDimension: .fractionalWidth(1/3)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: .fractionalWidth(1/3)
            )
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.boundarySupplementaryItems = [
                NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: NSCollectionLayoutSize(
                        widthDimension: .fractionalWidth(1),
                        heightDimension: .estimated(160)
                    ),
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
            ]
            return section
        }

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = UIColor(named: "DustySage")
        collectionView.contentInsetAdjustmentBehavior = .automatic
        collectionView.register(PlacePhotoCell.self, forCellWithReuseIdentifier: PlacePhotoCell.reuseID)
        collectionView.register(
            PlaceDetailHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: PlaceDetailHeader.reuseID
        )
        collectionView.dataSource = self
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Asset loading

    private func loadAssets() {
        let ids = summary.photoLocalIDs
        guard !ids.isEmpty else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let opts = PHFetchOptions()
            opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: opts)
            var assets: [PHAsset] = []
            result.enumerateObjects { asset, _, _ in assets.append(asset) }
            DispatchQueue.main.async {
                self.photoAssets = assets
                self.collectionView.reloadData()
            }
        }
    }
}

// MARK: - UICollectionViewDataSource

extension PlaceDetailViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        photoAssets.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PlacePhotoCell.reuseID, for: indexPath
        ) as! PlacePhotoCell
        cell.load(asset: photoAssets[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: PlaceDetailHeader.reuseID,
            for: indexPath
        ) as! PlaceDetailHeader
        header.configure(with: summary)
        return header
    }
}

// MARK: - Header

class PlaceDetailHeader: UICollectionReusableView {
    static let reuseID = "PlaceDetailHeader"

    private let titleLabel = UILabel()
    private let dateLabel  = UILabel()
    private let statsLabel = UILabel()
    private let divider    = UIView()

    private let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .long; f.timeStyle = .none; return f
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(named: "DustySage")

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font          = .fraunces(.bold, size: 26)
        titleLabel.textColor     = UIColor(named: "FogBackground")
        titleLabel.numberOfLines = 0
        addSubview(titleLabel)

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font      = .karla(.regular, size: 14)
        dateLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.60)
        addSubview(dateLabel)

        statsLabel.translatesAutoresizingMaskIntoConstraints = false
        statsLabel.font      = .karla(.regular, size: 13)
        statsLabel.textColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.45)
        addSubview(statsLabel)

        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.backgroundColor = UIColor(named: "FogBackground")?.withAlphaComponent(0.12)
        addSubview(divider)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 7),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            statsLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 3),
            statsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            divider.topAnchor.constraint(equalTo: statsLabel.bottomAnchor, constant: 18),
            divider.leadingAnchor.constraint(equalTo: leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 0.5),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with summary: PlaceSummary) {
        titleLabel.text = summary.placeName
        dateLabel.text  = "First visited \(dateFmt.string(from: summary.firstVisitDate))"
        let v = summary.visitCount, p = summary.totalPhotoCount
        statsLabel.text = "\(v) day\(v == 1 ? "" : "s") visited · \(p) photo\(p == 1 ? "" : "s")"
    }
}

// MARK: - Photo cell

class PlacePhotoCell: UICollectionViewCell {
    static let reuseID = "PlacePhotoCell"

    private let imageView = UIImageView()
    private var requestID: PHImageRequestID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = UIColor(named: "DeepPineInk")?.withAlphaComponent(0.08)
        contentView.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func prepareForReuse() {
        super.prepareForReuse()
        if let id = requestID { PHImageManager.default().cancelImageRequest(id); requestID = nil }
        imageView.image = nil
    }

    func load(asset: PHAsset) {
        let scale      = traitCollection.displayScale
        let side       = bounds.width * scale
        let targetSize = CGSize(width: side, height: side)
        let opts = PHImageRequestOptions()
        opts.deliveryMode           = .opportunistic
        opts.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize, contentMode: .aspectFill, options: opts
        ) { [weak self] image, _ in
            DispatchQueue.main.async { self?.imageView.image = image }
        }
    }
}
