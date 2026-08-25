@preconcurrency import CoreLocation
import Foundation

struct RoutePoint: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let timestamp: Date

    init(location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        timestamp = location.timestamp
    }

    init(
        latitude: Double,
        longitude: Double,
        altitude: Double,
        timestamp: Date
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.timestamp = timestamp
    }

    var location: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: timestamp
        )
    }
}

struct WorkoutResult: Sendable {
    let startedAt: Date
    let completedAt: Date
    let distanceMeters: Double
    let route: [RoutePoint]
}

@MainActor
final class WorkoutLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var route: [RoutePoint] = []
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()
    private var previousLocation: CLLocation?
    private var wantsToStart = false

    init(distanceMeters: Double = 0, route: [RoutePoint] = []) {
        self.distanceMeters = distanceMeters
        self.route = route
        previousLocation = route.last?.location
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.activityType = .fitness
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start() {
        wantsToStart = true
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            beginUpdates()
        case .denied, .restricted:
            errorMessage = L10n.locationPermissionDenied
        @unknown default:
            errorMessage = L10n.locationUnknown
        }
    }

    func stop() -> (distanceMeters: Double, route: [RoutePoint]) {
        wantsToStart = false
        manager.stopUpdatingLocation()
        previousLocation = nil
        return (distanceMeters, route)
    }

    func reset() {
        distanceMeters = 0
        route = []
        previousLocation = nil
        errorMessage = nil
    }

    func resetError() {
        errorMessage = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            authorizationStatus = status
            if wantsToStart, status == .authorizedAlways || status == .authorizedWhenInUse {
                beginUpdates()
            } else if wantsToStart, status == .denied || status == .restricted {
                errorMessage = L10n.locationPermissionDenied
            }
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        Task { @MainActor [weak self] in
            self?.process(locations)
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.errorMessage = L10n.locationUnavailable(error.localizedDescription)
        }
    }

    private func beginUpdates() {
        manager.allowsBackgroundLocationUpdates = Self.supportsBackgroundLocation(
            infoDictionary: Bundle.main.infoDictionary
        )
        manager.startUpdatingLocation()
    }

    static func supportsBackgroundLocation(
        infoDictionary: [String: Any]?
    ) -> Bool {
        guard let modes = infoDictionary?["UIBackgroundModes"] as? [String] else {
            return false
        }
        return modes.contains("location")
    }

    private func process(_ locations: [CLLocation]) {
        for location in locations where location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 50 {
            if let previousLocation {
                let interval = location.timestamp.timeIntervalSince(previousLocation.timestamp)
                let increment = location.distance(from: previousLocation)
                if interval > 0, increment >= 1, increment / interval < 12 {
                    distanceMeters += increment
                }
            }
            previousLocation = location
            route.append(RoutePoint(location: location))
        }
    }
}
