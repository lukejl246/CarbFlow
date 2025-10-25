import Foundation
#if canImport(HealthKit)
import HealthKit
#else
typealias HKSampleType = AnyHashable
typealias HKObjectType = AnyHashable
typealias HKSample = Any
#endif

final class HealthKitManager {
    static let shared = HealthKitManager()

#if canImport(HealthKit)
    private let healthStore = HKHealthStore()
#endif

    private init() {}

#if canImport(HealthKit)
    func requestAuthorization(toShare shareTypes: Set<HKSampleType>,
                              read readTypes: Set<HKObjectType>,
                              completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            reportPermissionDenied(forTypes: ["healthkit"], status: "unavailable", error: nil)
            DispatchQueue.main.async { completion(false) }
            return
        }

        healthStore.requestAuthorization(toShare: shareTypes, read: readTypes) { [weak self] success, error in
            DispatchQueue.main.async {
                if !success {
                    let identifiers = self?.collectIdentifiers(shareTypes: shareTypes, readTypes: readTypes) ?? []
                    let status = (error == nil) ? "denied" : "error"
                    self?.reportPermissionDenied(forTypes: identifiers, status: status, error: error)
                }
                completion(success)
            }
        }
    }

    func fetchSamples(of sampleType: HKSampleType,
                      predicate: NSPredicate? = nil,
                      limit: Int = HKObjectQueryNoLimit,
                      sortDescriptors: [NSSortDescriptor]? = nil,
                      completion: @escaping (Result<[HKSample], Error>) -> Void) {
        let query = HKSampleQuery(sampleType: sampleType,
                                  predicate: predicate,
                                  limit: limit,
                                  sortDescriptors: sortDescriptors) { [weak self] _, samples, error in
            DispatchQueue.main.async {
                if let error {
                    self?.reportQueryFailure(query: "HKSampleQuery",
                                              sampleTypeIdentifier: sampleType.identifier,
                                              error: error)
                    completion(.failure(error))
                } else {
                    completion(.success(samples ?? []))
                }
            }
        }

        healthStore.execute(query)
    }
#else
    func requestAuthorization(toShare shareTypes: Set<HKSampleType> = [],
                              read readTypes: Set<HKObjectType> = [],
                              completion: @escaping (Bool) -> Void) {
        reportPermissionDenied(forTypes: ["healthkit"], status: "unsupported", error: nil)
        DispatchQueue.main.async { completion(false) }
    }

    func fetchSamples(of sampleType: HKSampleType,
                      predicate: NSPredicate? = nil,
                      limit: Int = 0,
                      sortDescriptors: [NSSortDescriptor]? = nil,
                      completion: @escaping (Result<[HKSample], Error>) -> Void) {
        let error = NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit unavailable"])
        reportQueryFailure(query: "HKSampleQuery", sampleTypeIdentifier: String(describing: sampleType), error: error)
        DispatchQueue.main.async { completion(.failure(error)) }
    }
#endif

    func reportPermissionDenied(for typeIdentifier: String, status: String = "denied") {
        reportPermissionDenied(forTypes: [typeIdentifier], status: status, error: nil)
    }

    func reportQueryFailure(query: String, sampleTypeIdentifier: String, error: Error) {
        let nsError = error as NSError
        var context: [String: Any] = [
            "query": query,
            "sample_type": sampleTypeIdentifier
        ]
        let codeString = nsError.domain.isEmpty ? "\(nsError.code)" : "\(nsError.domain)#\(nsError.code)"
        cf_reportError(message: "hk_query_failed", code: codeString, context: context)
    }

#if canImport(HealthKit)
    private func collectIdentifiers(shareTypes: Set<HKSampleType>, readTypes: Set<HKObjectType>) -> [String] {
        var identifiers: [String] = []
        identifiers.append(contentsOf: shareTypes.map { $0.identifier })
        identifiers.append(contentsOf: readTypes.map { $0.identifier })
        return identifiers
    }

    private func reportPermissionDenied(forTypes identifiers: [String], status: String, error: Error?) {
        var context: [String: Any] = [
            "type": identifiers.joined(separator: ","),
            "status": status
        ]
        if let nsError = error as NSError? {
            context["code"] = nsError.code
        }
        cf_reportInfo(message: "hk_permission_denied", context: context)
    }
#else
    private func reportPermissionDenied(forTypes identifiers: [String], status: String, error: Error?) {
        cf_reportInfo(message: "hk_permission_denied", context: [
            "type": identifiers.joined(separator: ","),
            "status": status
        ])
    }
#endif
}
