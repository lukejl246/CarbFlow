import CoreData
import Foundation

actor CFOfflineFoodOps {
    private let persistence: CFPersistence
    private let repository: UserFoodRepository
    private let logURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(persistence: CFPersistence, repository: UserFoodRepository) {
        self.persistence = persistence
        self.repository = repository
        self.logURL = Self.makeLogURL()

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    // MARK: - Public API

    func queueCreate(_ input: NewUserFoodInput) async {
        let payload = LoggedNewFoodInput(input: input)
        await append(FoodOpQueued(payload: .create(payload)))
    }

    func queueUpdate(id: UUID, mutate patch: FoodPatch) async {
        await append(FoodOpQueued(payload: .update(FoodUpdatePayload(id: id, patch: patch))))
    }

    func queueDelete(id: UUID) async {
        await append(FoodOpQueued(payload: .delete(id)))
    }

    func replayPendingOperations() async {
        let entries = loadLog()
        guard !entries.isEmpty else { return }

        var failures: [FoodOpQueued] = []
        for entry in entries {
            let succeeded = await apply(entry)
            if !succeeded {
                failures.append(entry)
            }
        }

        if failures.isEmpty {
            try? FileManager.default.removeItem(at: logURL)
        } else {
            persist(entries: failures, replacing: true)
        }
    }

    // MARK: - Persistence

    private func append(_ entry: FoodOpQueued) async {
        persist(entries: [entry], replacing: false)
    }

    private func loadLog() -> [FoodOpQueued] {
        guard FileManager.default.fileExists(atPath: logURL.path),
              let data = try? Data(contentsOf: logURL),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var entries: [FoodOpQueued] = []
        entries.reserveCapacity(16)

        for line in content.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let entry = try? decoder.decode(FoodOpQueued.self, from: lineData) else {
                continue
            }
            entries.append(entry)
        }

        return entries
    }

    private func persist(entries: [FoodOpQueued], replacing: Bool) {
        guard !entries.isEmpty else { return }

        if replacing {
            let directory = logURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = entries.compactMap { encode(entry: $0) }.reduce(into: Data()) { result, part in
                result.append(part)
            }
            try? data.write(to: logURL, options: .atomic)
            return
        }

        if !FileManager.default.fileExists(atPath: logURL.path) {
            let directory = logURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }

        handle.seekToEndOfFile()
        for entry in entries {
            if let data = encode(entry: entry) {
                handle.write(data)
            }
        }
    }

    private func encode(entry: FoodOpQueued) -> Data? {
        guard let data = try? encoder.encode(entry) else { return nil }
        var buffer = data
        buffer.append(0x0A)
        return buffer
    }

    private static func makeLogURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory
        let directory = base.appendingPathComponent("CarbFlow", isDirectory: true)
        if !fm.fileExists(atPath: directory.path) {
            try? fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("cf_food_ops.jsonl")
    }

    // MARK: - Application

    private func apply(_ entry: FoodOpQueued) async -> Bool {
        switch entry.payload {
        case .create(let logged):
            do {
                _ = try await repository.create(logged.asNewUserFoodInput())
                return true
            } catch UserFoodRepositoryError.duplicate {
                return true
            } catch {
                return false
            }

        case .update(let payload):
            do {
                let objectID = try await lookupObjectID(for: payload.id)
                try await repository.update(id: objectID, with: payload.patch)
                return true
            } catch UserFoodRepositoryError.notFound {
                return true
            } catch {
                return false
            }

        case .delete(let id):
            do {
                let objectID = try await lookupObjectID(for: id)
                try await repository.softDelete(id: objectID)
                return true
            } catch UserFoodRepositoryError.notFound {
                return true
            } catch {
                return false
            }
        }
    }

    private func lookupObjectID(for id: UUID) async throws -> NSManagedObjectID {
        let context = await MainActor.run { persistence.newBackgroundContext() }
        return try await withCheckedThrowingContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<NSManagedObjectID>(entityName: "Food")
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.resultType = .managedObjectIDResultType
                request.fetchLimit = 1

                do {
                    if let objectID = try context.fetch(request).first {
                        continuation.resume(returning: objectID)
                    } else {
                        continuation.resume(throwing: UserFoodRepositoryError.notFound)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Supporting types

private struct FoodOpQueued: Codable, Sendable {
    let tempId: UUID
    let timestamp: Date
    let payload: FoodOpPayload

    init(payload: FoodOpPayload) {
        self.tempId = UUID()
        self.timestamp = Date()
        self.payload = payload
    }
}

private enum FoodOpPayload: Codable, Sendable {
    case create(LoggedNewFoodInput)
    case update(FoodUpdatePayload)
    case delete(UUID)

    private enum CodingKeys: String, CodingKey {
        case type
        case create
        case update
        case delete
    }

    private enum PayloadType: String, Codable {
        case create
        case update
        case delete
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(PayloadType.self, forKey: .type)

        switch type {
        case .create:
            let value = try container.decode(LoggedNewFoodInput.self, forKey: .create)
            self = .create(value)
        case .update:
            let value = try container.decode(FoodUpdatePayload.self, forKey: .update)
            self = .update(value)
        case .delete:
            let value = try container.decode(UUID.self, forKey: .delete)
            self = .delete(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .create(let input):
            try container.encode(PayloadType.create, forKey: .type)
            try container.encode(input, forKey: .create)
        case .update(let payload):
            try container.encode(PayloadType.update, forKey: .type)
            try container.encode(payload, forKey: .update)
        case .delete(let id):
            try container.encode(PayloadType.delete, forKey: .type)
            try container.encode(id, forKey: .delete)
        }
    }
}

private struct FoodUpdatePayload: Codable, Sendable {
    let id: UUID
    let patch: FoodPatch
}

struct FoodPatch: Codable, Sendable {
    var name: String?
    var brand: Update<String>?
    var servingSizeValue: Update<Double>?
    var servingSizeUnit: Update<String>?
    var netCarbsPer100g: Double?
    var proteinPer100g: Double?
    var fatPer100g: Double?
    var notes: Update<String>?
    var upc: Update<String>?
    var updatedAt: Date?
}

enum Update<Value: Codable & Sendable>: Codable, Sendable {
    case set(Value)
    case clear

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .clear
        } else {
            let value = try container.decode(Value.self)
            self = .set(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .set(let value):
            try container.encode(value)
        case .clear:
            try container.encodeNil()
        }
    }
}

private struct LoggedNewFoodInput: Codable, Sendable {
    var name: String
    var brand: String?
    var servingSizeValue: Double?
    var servingSizeUnit: String?
    var netCarbsPer100g: Double
    var proteinPer100g: Double
    var fatPer100g: Double
    var notes: String?

    init(input: NewUserFoodInput) {
        self.name = input.name
        self.brand = input.brand
        self.servingSizeValue = input.servingSizeValue
        self.servingSizeUnit = input.servingSizeUnit
        self.netCarbsPer100g = input.netCarbsPer100g
        self.proteinPer100g = input.proteinPer100g
        self.fatPer100g = input.fatPer100g
        self.notes = input.notes
    }

    func asNewUserFoodInput() -> NewUserFoodInput {
        NewUserFoodInput(
            name: name,
            brand: brand,
            servingSizeValue: servingSizeValue,
            servingSizeUnit: servingSizeUnit,
            netCarbsPer100g: netCarbsPer100g,
            proteinPer100g: proteinPer100g,
            fatPer100g: fatPer100g,
            notes: notes
        )
    }
}
