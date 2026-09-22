import MapKit

// Maps MapKit's 83 raw POI categories (39 @ iOS13, 33 @ iOS18, 11 @ iOS27) down to the ~12
// PlaceCategoryGroup buckets Stage 3 actually scores against and Stage 6 actually learns on.
// MKPointOfInterestCategory is a String-rawValue struct, not an enum, so the iOS-27 constants
// can't sit in a single top-level dictionary literal on this 26.5-deployment-target app — they're
// isolated behind their own `@available` accessor instead.
nonisolated enum POICategoryMap {

    static func group(for category: MKPointOfInterestCategory) -> PlaceCategoryGroup {
        if let group = baseGroups[category] { return group }
        if let group = extendedGroups[category] { return group }
        if #available(iOS 27.0, *), let group = iOS27Groups[category] { return group }
        return .unknown
    }

    // Category weight table from the algorithm spec, collapsed onto PlaceCategoryGroup.
    static func weight(for group: PlaceCategoryGroup) -> Double {
        switch group {
        case .outdoors, .culture:  return 1.0
        case .nightlife:           return 0.9
        case .foodAndDrink, .lodging, .fitness: return 0.85
        case .transit, .retail:    return 0.6
        case .education:          return 0.6
        case .services:           return 0.2
        case .utility:            return 0.05
        case .unknown:            return 0.5
        }
    }

    private static let baseGroups: [MKPointOfInterestCategory: PlaceCategoryGroup] = [
        // outdoors
        .beach: .outdoors, .campground: .outdoors, .marina: .outdoors, .park: .outdoors,
        .nationalPark: .outdoors,
        // culture / attractions
        .museum: .culture, .theater: .culture, .zoo: .culture, .aquarium: .culture,
        .amusementPark: .culture, .stadium: .culture,
        // nightlife
        .nightlife: .nightlife, .brewery: .nightlife, .winery: .nightlife, .movieTheater: .nightlife,
        // food & drink
        .restaurant: .foodAndDrink, .cafe: .foodAndDrink, .bakery: .foodAndDrink, .foodMarket: .foodAndDrink,
        // lodging
        .hotel: .lodging,
        // fitness
        .fitnessCenter: .fitness,
        // education
        .school: .education, .university: .education, .library: .education,
        // transit
        .airport: .transit, .publicTransport: .transit,
        // retail
        .store: .retail,
        // services
        .bank: .services, .pharmacy: .services, .postOffice: .services, .laundry: .services,
        .carRental: .services, .hospital: .services, .fireStation: .services, .police: .services,
        // utility — kept far below `services` so a pit stop never becomes a "first"
        .gasStation: .utility, .parking: .utility, .atm: .utility, .evCharger: .utility, .restroom: .utility,
    ]

    // iOS 18 categories — no @available guard needed, the deployment target is 26.5.
    private static let extendedGroups: [MKPointOfInterestCategory: PlaceCategoryGroup] = [
        .castle: .culture, .fortress: .culture, .nationalMonument: .culture, .musicVenue: .culture,
        .planetarium: .culture, .conventionCenter: .culture, .bowling: .culture, .fairground: .culture,
        .distillery: .nightlife,
        .golf: .outdoors, .kayaking: .outdoors, .fishing: .outdoors, .skiing: .outdoors,
        .surfing: .outdoors, .swimming: .outdoors, .tennis: .outdoors, .volleyball: .outdoors,
        .hiking: .outdoors, .rvPark: .outdoors, .baseball: .outdoors, .basketball: .outdoors,
        .soccer: .outdoors, .miniGolf: .outdoors, .skatePark: .outdoors, .skating: .outdoors,
        .rockClimbing: .outdoors, .goKart: .outdoors,
        .spa: .fitness, .beauty: .fitness,
        .animalService: .services, .automotiveRepair: .services, .mailbox: .services,
    ]

    @available(iOS 27.0, *)
    private static let iOS27Groups: [MKPointOfInterestCategory: PlaceCategoryGroup] = [
        .picnicArea: .outdoors, .rangerStation: .outdoors, .scenicView: .outdoors,
        .airportTerminal: .transit,
        .automotiveDealership: .retail, .commercialVehicleDealership: .retail, .motorbikeDealership: .retail,
        .informationBooth: .services, .ticketOffice: .services, .visitorCenter: .services,
        .restArea: .utility,
    ]
}
