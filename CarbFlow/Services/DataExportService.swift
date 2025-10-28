import Foundation
import CoreData

@MainActor
final class DataExportService {
    private let context: NSManagedObjectContext
    private let userDefaults: UserDefaults

    init(
        context: NSManagedObjectContext = PersistenceController.shared.container.viewContext,
        userDefaults: UserDefaults = .standard
    ) {
        self.context = context
        self.userDefaults = userDefaults
    }

    func exportData() throws -> URL {
        let foods = try fetchFoods()
        let logs = try fetchLogs()
        let settings = collectSettings()

        let payload = ExportPayload(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            appVersion: AppVersion.versionKey(),
            foods: foods,
            logEntries: logs,
            settings: settings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)

        let fileName = "CarbFlow-Export-\(timestampString()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func fetchFoods() throws -> [ExportPayload.Food] {
        let request: NSFetchRequest<FoodItem> = FoodItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let items = try context.fetch(request)
        return items.map {
            ExportPayload.Food(
                id: $0.id,
                name: $0.name,
                brand: $0.brand,
                servingSizeGrams: $0.servingSize,
                carbs: $0.carbs,
                netCarbs: $0.netCarbs,
                fat: $0.fat,
                protein: $0.protein,
                kcal: $0.kcal,
                upc: $0.upc,
                isVerified: $0.isVerified,
                internalReviewNote: $0.internalReviewNote,
                isUserCreated: $0.isUserCreated,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }
    }

    private func fetchLogs() throws -> [ExportPayload.Log] {
        let request: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        let entries = try context.fetch(request)
        return entries.map {
            ExportPayload.Log(
                id: $0.id,
                date: $0.date,
                servings: $0.servings,
                foodName: $0.foodName,
                brand: $0.brand,
                upc: $0.upc,
                carbs: $0.carbs,
                netCarbs: $0.netCarbs,
                fat: $0.fat,
                protein: $0.protein,
                kcal: $0.kcal,
                servingSizeGrams: $0.servingSize
            )
        }
    }

    private func collectSettings() -> [ExportPayload.Setting] {
        let rawSettings = userDefaults.dictionaryRepresentation()
        let filteredKeys = rawSettings.keys.filter { $0.hasPrefix("cf_") }
        return filteredKeys.sorted().compactMap { key in
            guard let value = rawSettings[key] else { return nil }
            return ExportPayload.Setting(key: key, value: SettingValue(value))
        }
    }

    private func timestampString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private enum SettingValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([SettingValue])
    case dictionary([String: SettingValue])
    case null

    init(_ value: Any) {
        switch value {
        case let string as String:
            self = .string(string)
        case let int as Int:
            self = .int(int)
        case let double as Double:
            self = .double(double)
        case let bool as Bool:
            self = .bool(bool)
        case let array as [Any]:
            self = .array(array.map { SettingValue($0) })
        case let dict as [String: Any]:
            let mapped = dict.mapValues { SettingValue($0) }
            self = .dictionary(mapped)
        default:
            self = .string(String(describing: value))
        }
    }
}

private struct ExportPayload: Codable {
    struct Food: Codable {
        let id: UUID
        let name: String
        let brand: String?
        let servingSizeGrams: Double?
        let carbs: Double
        let netCarbs: Double
        let fat: Double
        let protein: Double
        let kcal: Double
        let upc: String?
        let isVerified: Bool
        let internalReviewNote: String?
        let isUserCreated: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct Log: Codable {
        let id: UUID
        let date: Date
        let servings: Double
        let foodName: String
        let brand: String?
        let upc: String?
        let carbs: Double
        let netCarbs: Double
        let fat: Double
        let protein: Double
        let kcal: Double
        let servingSizeGrams: Double?
    }

    struct Setting: Codable {
        let key: String
        let value: SettingValue
    }

    let generatedAt: String
    let appVersion: String
    let foods: [Food]
    let logEntries: [Log]
    let settings: [Setting]
}
