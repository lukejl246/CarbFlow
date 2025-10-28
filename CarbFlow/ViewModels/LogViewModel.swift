import Foundation
import Combine
import CoreData

@MainActor
final class LogViewModel: ObservableObject {
    enum Presentation: Identifiable {
        case add(food: FoodItem)
        case notFound(code: String, message: String)

        var id: String {
            switch self {
            case .add(let food):
                return food.objectID.uriRepresentation().absoluteString
            case .notFound(let code, let message):
                return "\(code)-\(message)"
            }
        }
    }

    @Published var lastScannedCode: String?
    @Published var activePresentation: Presentation?

    private let foodStore: FoodStore
    private let persistence: PersistenceController
    private let cloudLookup: CloudFoodLookupServicing

    init(
        foodStore: FoodStore? = nil,
        persistence: PersistenceController? = nil,
        cloudLookup: CloudFoodLookupServicing? = nil
    ) {
        self.foodStore = foodStore ?? FoodStore()
        self.persistence = persistence ?? PersistenceController.shared
        self.cloudLookup = cloudLookup ?? CloudFoodLookup()
    }

    func handleScanned(code: String) {
        let timestamp = Date().timeIntervalSince1970
        cf_logEvent("scan-detected", ["ts": timestamp])
        cf_breadcrumbAction("log_scan_detected", data: ["code": code])
        lastScannedCode = code

        if let food = foodStore.item(forUPC: code) {
            cf_logEvent("scan-lookup-hit", ["ts": Date().timeIntervalSince1970])
            activePresentation = .add(food: food)
            return
        }

        cf_logEvent("scan-lookup-miss", ["ts": Date().timeIntervalSince1970])
        activePresentation = .notFound(
            code: code,
            message: "We couldn't find that barcode yet. Search the library or add it manually."
        )

        Task {
            _ = await cloudLookup.lookup(upc: code)
        }
    }

    func addToLog(food: FoodItem, servings: Double) {
        let clampedServings = max(0.1, servings)
        let context = persistence.container.viewContext
        _ = LogEntry(context: context, food: food, servings: clampedServings, date: Date())

        do {
            try context.save()
            let params: [String: Any] = [
                "servings": clampedServings,
                "ts": Date().timeIntervalSince1970
            ]
            cf_logEvent("scan-add-to-log", params)
            cf_breadcrumbAction("log_entry_saved", data: [
                "servings": "\(clampedServings)",
                "upc": food.upc ?? lastScannedCode ?? ""
            ])
        } catch {
            cf_reportError(
                message: "log_entry_save_failed",
                code: nil,
                context: ["error": error.localizedDescription, "code": food.upc ?? ""]
            )
        }

        activePresentation = nil
    }

    func dismissPresentation() {
        activePresentation = nil
    }

    func trackSearchLibrary(for code: String) {
        cf_logEvent("scan-lookup-action-search", ["ts": Date().timeIntervalSince1970])
        cf_breadcrumbAction("log_scan_search", data: ["code": code])
        activePresentation = nil
    }

    func trackCreateCustom(for code: String) {
        cf_logEvent("scan-lookup-action-custom", ["ts": Date().timeIntervalSince1970])
        cf_breadcrumbAction("log_scan_custom", data: ["code": code])
        activePresentation = nil
    }
}
