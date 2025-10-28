import CoreData
import Foundation

enum CFSeedInstaller {
    static func installIfNeeded(
        seedResourceName: String,
        seedVersion: Int64,
        context: NSManagedObjectContext
    ) {
        context.perform {
            do {
                let currentMeta = try fetchMetaSeed(in: context)
                let currentVersion = currentMeta?.version ?? 0
                guard currentVersion < seedVersion else {
                    #if DEBUG
                    print("[CFSeedInstaller] Seed version \(currentVersion) already applied")
                    #endif
                    return
                }

                guard let url = locateSeedResource(named: seedResourceName) else {
                    #if DEBUG
                    print("[CFSeedInstaller] Seed resource \(seedResourceName).json not found")
                    #endif
                    return
                }

                let data = try Data(contentsOf: url)
                let (records, discardedCount) = try decodeSeedRecords(from: data)

                guard !records.isEmpty else {
                    #if DEBUG
                    print("[CFSeedInstaller] No valid records decoded (discarded=\(discardedCount))")
                    #endif
                    return
                }

                let timestamp = Date()
                let metrics = try upsert(records: records, timestamp: timestamp, context: context)

                let meta = currentMeta ?? MetaSeed(context: context)
                meta.version = seedVersion
                meta.appliedAt = timestamp

                if context.hasChanges {
                    try context.save()
                }

                #if DEBUG
                print("[CFSeedInstaller] Seed applied v\(seedVersion) inserted=\(metrics.inserted) updated=\(metrics.updated) discarded=\(discardedCount)")
                #endif
            } catch {
                context.rollback()
                #if DEBUG
                print("[CFSeedInstaller] Failed to install seed: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Helpers

private extension CFSeedInstaller {
    static func fetchMetaSeed(in context: NSManagedObjectContext) throws -> MetaSeed? {
        let request: NSFetchRequest<MetaSeed> = MetaSeed.fetchRequest()
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    static func locateSeedResource(named name: String) -> URL? {
        let candidates: [Bundle] = [
            .main,
            Bundle(for: BundleSentinel.self)
        ]

        for bundle in candidates {
            if let url = bundle.url(forResource: name, withExtension: "json") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Seeds") {
                return url
            }
            if let url = bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources/Seeds") {
                return url
            }
        }

        return nil
    }

    static func decodeSeedRecords(from data: Data) throws -> ([SeedFoodRecord], Int) {
        let decoder = JSONDecoder()
        let wrapper = try decoder.decode(LossySeedFoodWrapper.self, from: data)
        return (wrapper.items, wrapper.discardedCount)
    }

    static func upsert(
        records: [SeedFoodRecord],
        timestamp: Date,
        context: NSManagedObjectContext
    ) throws -> (inserted: Int, updated: Int) {
        let ids = records.map(\.id)
        let fetchRequest: NSFetchRequest<Food> = Food.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id IN %@", ids)
        let existingFoods = try context.fetch(fetchRequest)

        var existingLookup: [UUID: Food] = [:]
        for food in existingFoods {
            guard let identifier = food.id else { continue }
            existingLookup[identifier] = food
        }

        var dictionariesForInsert: [[String: Any]] = []
        var recordsForInsert: [SeedFoodRecord] = []
        var seen: Set<UUID> = []
        var inserted = 0
        var updated = 0

        for record in records {
            guard seen.insert(record.id).inserted else { continue }
            if let managed = existingLookup[record.id] {
                apply(record: record, to: managed, timestamp: timestamp)
                updated += 1
            } else {
                dictionariesForInsert.append(record.makeInsertDictionary(timestamp: timestamp))
                recordsForInsert.append(record)
            }
        }

        if !dictionariesForInsert.isEmpty {
            let supportsBatchInsert = context.persistentStoreCoordinator?.persistentStores.allSatisfy { store in
                store.type == NSSQLiteStoreType
            } ?? false

            if supportsBatchInsert {
                let request = NSBatchInsertRequest(entityName: "Food", objects: dictionariesForInsert)
                request.resultType = .objectIDs
                let result = try context.execute(request) as? NSBatchInsertResult
                if let objectIDs = result?.result as? [NSManagedObjectID], !objectIDs.isEmpty {
                    let changes = [NSInsertedObjectsKey: objectIDs]
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: changes,
                        into: [context]
                    )
                }
                inserted = dictionariesForInsert.count
            } else {
                for record in recordsForInsert {
                    let food = Food(context: context)
                    food.id = record.id
                    food.createdAt = timestamp
                    apply(record: record, to: food, timestamp: timestamp)
                    food.updatedAt = timestamp
                    inserted += 1
                }
            }
        }

        return (inserted, updated)
    }

    static func apply(
        record: SeedFoodRecord,
        to food: Food,
        timestamp: Date
    ) {
        food.name = record.name
        food.brand = record.brand
        food.portionGram = record.portionGram
        food.netCarbsPer100g = record.netCarbsPer100g
        food.proteinPer100g = record.proteinPer100g
        food.fatPer100g = record.fatPer100g
        food.isVerified = true
        food.updatedAt = timestamp
    }
}

// MARK: - Seed decoding

private struct LossySeedFoodWrapper: Decodable {
    let items: [SeedFoodRecord]
    let discardedCount: Int

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var decoded: [SeedFoodRecord] = []
        var discarded = 0

        while !container.isAtEnd {
            do {
                let record = try container.decode(SeedFoodRecord.self)
                decoded.append(record)
            } catch {
                discarded += 1
                _ = try? container.decode(DiscardableSeed.self)
            }
        }

        self.items = decoded
        self.discardedCount = discarded
    }

    private struct DiscardableSeed: Decodable {}
}

private struct SeedFoodRecord: Decodable {
    let id: UUID
    let name: String
    let brand: String?
    let portionGram: Double
    let netCarbsPer100g: Double
    let proteinPer100g: Double
    let fatPer100g: Double

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case brand
        case portionGram
        case netCarbsPer100g
        case proteinPer100g
        case fatPer100g
        case isVerified
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .name,
                in: container,
                debugDescription: "Name must not be empty"
            )
        }

        if let rawBrand = try container.decodeIfPresent(String.self, forKey: .brand)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !rawBrand.isEmpty {
            brand = rawBrand
        } else {
            brand = nil
        }

        portionGram = try container.decode(Double.self, forKey: .portionGram)
        netCarbsPer100g = try container.decode(Double.self, forKey: .netCarbsPer100g)
        proteinPer100g = try container.decode(Double.self, forKey: .proteinPer100g)
        fatPer100g = try container.decode(Double.self, forKey: .fatPer100g)

        let isVerified = try container.decode(Bool.self, forKey: .isVerified)
        guard isVerified else {
            throw DecodingError.dataCorruptedError(
                forKey: .isVerified,
                in: container,
                debugDescription: "Seeded items must be verified"
            )
        }
    }

    func makeInsertDictionary(timestamp: Date) -> [String: Any] {
        var payload: [String: Any] = [
            "id": id,
            "name": name,
            "portionGram": portionGram,
            "netCarbsPer100g": netCarbsPer100g,
            "proteinPer100g": proteinPer100g,
            "fatPer100g": fatPer100g,
            "isVerified": true,
            "createdAt": timestamp,
            "updatedAt": timestamp
        ]

        payload["brand"] = brand
        return payload
    }
}

private final class BundleSentinel {}
