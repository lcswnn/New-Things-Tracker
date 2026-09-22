import Foundation
import Photos

// Stage 1 photo ingest. Unlike the PhotoMetadataManager it replaces, this actually applies the
// spec's accuracy/coordinate filters: drop horizontalAccuracy > 200m or negative, and drop (0,0).
nonisolated enum PhotoLibrarySource {

    static func fetchPhotoSignals() -> [PresenceSignalDraft] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let assets = PHAsset.fetchAssets(with: .image, options: options)

        var drafts: [PresenceSignalDraft] = []
        assets.enumerateObjects { asset, _, _ in
            guard !asset.mediaSubtypes.contains(.photoScreenshot),
                  let date = asset.creationDate,
                  let location = asset.location,
                  location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 200,
                  !(location.coordinate.latitude == 0 && location.coordinate.longitude == 0)
            else { return }

            drafts.append(PresenceSignalDraft(
                kind: .photo,
                timestamp: date,
                endTimestamp: nil,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                horizontalAccuracy: location.horizontalAccuracy,
                assetLocalIdentifier: asset.localIdentifier
            ))
        }
        return drafts
    }
}
