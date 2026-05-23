import Foundation
import HealthKit
import CoreLocation

@MainActor
class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()

    @Published var isAuthorized = false
    @Published var isLoading = false
    @Published var dives: [Dive] = []
    @Published var error: HealthKitError?

    private let typesToRead: Set<HKObjectType> = {
        var types: Set<HKObjectType> = [HKObjectType.workoutType()]
        let identifiers: [HKQuantityTypeIdentifier] = [
            .underwaterDepth,
            .waterTemperature,
            .heartRate,
        ]
        for id in identifiers {
            if let type = HKObjectType.quantityType(forIdentifier: id) {
                types.insert(type)
            }
        }
        return types
    }()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        isAuthorized = true
        try await fetchDives()
    }

    func fetchDives() async throws {
        isLoading = true
        defer { isLoading = false }

        let workoutPredicate = HKQuery.predicateForWorkouts(with: .underwaterDiving)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let workouts: [HKWorkout] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: .workoutType(),
                predicate: workoutPredicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }

        var fetched: [Dive] = []
        for workout in workouts {
            let profile = try await fetchDepthProfile(for: workout)
            let location = try await fetchLocation(for: workout)
            let dive = makeDive(from: workout, profile: profile, location: location)
            fetched.append(dive)
        }
        dives = fetched
    }

    // MARK: - Private

    private func fetchDepthProfile(for workout: HKWorkout) async throws -> [DepthSample] {
        guard let depthType = HKObjectType.quantityType(forIdentifier: .underwaterDepth) else {
            return []
        }
        let predicate = HKQuery.predicateForObjects(from: workout)

        return try await withCheckedThrowingContinuation { continuation in
            var samples: [DepthSample] = []

            let query = HKQuantitySeriesSampleQuery(quantityType: depthType, predicate: predicate) { _, quantity, interval, _, done, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let quantity, let interval {
                    samples.append(DepthSample(
                        id: UUID(),
                        timestamp: interval.start,
                        depth: quantity.doubleValue(for: .meter())
                    ))
                }
                if done {
                    // Attach elapsed time relative to dive start
                    let start = workout.startDate
                    let resolved = samples
                        .sorted { $0.timestamp < $1.timestamp }
                        .map { s -> DepthSample in
                            var m = s
                            m.elapsedSeconds = s.timestamp.timeIntervalSince(start)
                            return m
                        }
                    continuation.resume(returning: resolved)
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchLocation(for workout: HKWorkout) async throws -> DiveLocation? {
        guard let routeType = HKObjectType.seriesType(forIdentifier: HKWorkoutRouteTypeIdentifier) else {
            return nil
        }
        let predicate = HKQuery.predicateForObjects(from: workout)

        let routes: [HKWorkoutRoute] = try await withCheckedThrowingContinuation { cont in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error { cont.resume(throwing: error); return }
                cont.resume(returning: (samples as? [HKWorkoutRoute]) ?? [])
            }
            healthStore.execute(query)
        }

        guard let route = routes.first else { return nil }

        var firstLocation: CLLocation?
        let _: Void = try await withCheckedThrowingContinuation { cont in
            let query = HKWorkoutRouteQuery(route: route) { _, locations, done, error in
                if let error { cont.resume(throwing: error); return }
                if firstLocation == nil { firstLocation = locations?.first }
                if done { cont.resume(returning: ()) }
            }
            healthStore.execute(query)
        }

        guard let loc = firstLocation else { return nil }
        return DiveLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
    }

    private func makeDive(from workout: HKWorkout, profile: [DepthSample], location: DiveLocation?) -> Dive {
        let depths = profile.map(\.depth)
        let maxDepth = depths.max() ?? 0
        let avgDepth = depths.isEmpty ? 0 : depths.reduce(0, +) / Double(depths.count)

        var waterTemp: Double?
        if let meta = workout.metadata,
           let tempQuantity = meta[HKMetadataKeyWaterTemperature] as? HKQuantity {
            waterTemp = tempQuantity.doubleValue(for: HKUnit.degreeCelsius())
        }

        return Dive(
            id: UUID(),
            date: workout.startDate,
            duration: workout.duration,
            maxDepth: maxDepth,
            avgDepth: avgDepth,
            waterTemperature: waterTemp,
            location: location,
            profile: profile,
            buddyIDs: [],
            notes: "",
            workoutID: workout.uuid
        )
    }

    enum HealthKitError: LocalizedError {
        case notAvailable
        case unauthorized

        var errorDescription: String? {
            switch self {
            case .notAvailable: return "HealthKit is not available on this device."
            case .unauthorized: return "Health access was denied. Enable it in Settings > Privacy > Health."
            }
        }
    }
}
