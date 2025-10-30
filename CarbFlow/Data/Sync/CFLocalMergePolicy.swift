import Foundation

struct FoodDTO {
    var id: UUID?
    var name: String
    var brand: String?
    var slug: String
    var isUserCreated: Bool
    var notes: String?
    var source: String
    var updatedAt: Date

    init(
        id: UUID? = nil,
        name: String,
        brand: String? = nil,
        slug: String? = nil,
        isUserCreated: Bool,
        notes: String? = nil,
        source: String = "user",
        updatedAt: Date
    ) {
        let normalizedName = normaliseName(name)
        let normalizedBrand = brand.map(normaliseName)

        var resolvedSlug = slug ?? makeSlug(name: normalizedName, brand: normalizedBrand)
        if resolvedSlug.isEmpty {
            resolvedSlug = UUID().uuidString.lowercased()
        }

        self.id = id
        self.name = normalizedName
        self.brand = normalizedBrand
        self.slug = resolvedSlug
        self.isUserCreated = isUserCreated
        self.notes = notes
        self.source = source
        self.updatedAt = updatedAt
    }
}

enum FoodChangeOp {
    case create(FoodDTO)
    case update(id: UUID, FoodDTO)
    case softDelete(id: UUID)
}

struct CFLocalMergePolicy {
    func resolveConflicts(_ ops: [FoodChangeOp]) -> [FoodChangeOp] {
        var idToSlug: [UUID: String] = [:]
        var normalisedOps: [TaggedOp] = []
        normalisedOps.reserveCapacity(ops.count)

        for (index, op) in ops.enumerated() {
            let tagged = normalise(op, index: index, idToSlug: &idToSlug)
            normalisedOps.append(tagged)
        }

        var winners: [String: TaggedOp] = [:]
        for tagged in normalisedOps {
            guard let slug = tagged.slug, let updatedAt = tagged.updatedAt else { continue }
            if let existing = winners[slug], let existingUpdatedAt = existing.updatedAt {
                if updatedAt > existingUpdatedAt
                    || (updatedAt == existingUpdatedAt && tagged.index > existing.index) {
                    winners[slug] = tagged
                }
            } else {
                winners[slug] = tagged
            }
        }

        var resolved: [FoodChangeOp] = []
        resolved.reserveCapacity(normalisedOps.count)

        for tagged in normalisedOps {
            if let slug = tagged.slug, winners[slug]?.index != tagged.index {
                continue
            }
            resolved.append(tagged.op)
        }

        return resolved
    }
}

private extension CFLocalMergePolicy {
    struct TaggedOp {
        let op: FoodChangeOp
        let slug: String?
        let updatedAt: Date?
        let index: Int
    }

    func normalise(
        _ op: FoodChangeOp,
        index: Int,
        idToSlug: inout [UUID: String]
    ) -> TaggedOp {
        switch op {
        case .create(var dto):
            dto = sanitize(dto)
            if let id = dto.id {
                idToSlug[id] = dto.slug
            }
            return TaggedOp(op: .create(dto), slug: dto.slug, updatedAt: dto.updatedAt, index: index)

        case .update(let id, var dto):
            dto = sanitize(dto)
            if dto.isUserCreated {
                idToSlug[id] = dto.slug
                return TaggedOp(op: .update(id: id, dto), slug: dto.slug, updatedAt: dto.updatedAt, index: index)
            } else {
                var forkedDTO = dto
                forkedDTO.id = UUID()
                forkedDTO.isUserCreated = true
                forkedDTO.source = "user"
                forkedDTO.notes = annotatedNotes(existing: forkedDTO.notes, seedID: id)
                forkedDTO = sanitize(forkedDTO)
                if let newId = forkedDTO.id {
                    idToSlug[newId] = forkedDTO.slug
                }
                return TaggedOp(
                    op: .create(forkedDTO),
                    slug: forkedDTO.slug,
                    updatedAt: forkedDTO.updatedAt,
                    index: index
                )
            }

        case .softDelete(let id):
            let slug = idToSlug[id]
            return TaggedOp(op: op, slug: slug, updatedAt: nil, index: index)
        }
    }

    func sanitize(_ dto: FoodDTO) -> FoodDTO {
        FoodDTO(
            id: dto.id,
            name: dto.name,
            brand: dto.brand,
            slug: dto.slug,
            isUserCreated: dto.isUserCreated,
            notes: dto.notes,
            source: dto.source,
            updatedAt: dto.updatedAt
        )
    }

    func annotatedNotes(existing: String?, seedID: UUID) -> String {
        let tag = "based on: \(seedID.uuidString.lowercased())"
        guard let existing else { return tag }

        if existing.lowercased().contains(tag) {
            return existing
        }

        if existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return tag
        }

        return existing + "\n" + tag
    }
}
