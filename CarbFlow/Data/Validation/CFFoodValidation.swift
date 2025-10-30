import Foundation

enum FoodValidationError: Error {
    case emptyName
    case invalidMacros
    case invalidServing
}

func normaliseName(_ s: String) -> String {
    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }

    let collapsed = trimmed
        .split(whereSeparator: { $0.isWhitespace })
        .joined(separator: " ")

    return collapsed
}

func makeSlug(name: String, brand: String?) -> String {
    var parts: [String] = []

    let namePart = normaliseName(name).lowercased()
    if !namePart.isEmpty {
        parts.append(namePart)
    }

    if let brand, !brand.isEmpty {
        let brandPart = normaliseName(brand).lowercased()
        if !brandPart.isEmpty {
            parts.append(brandPart)
        }
    }

    let base = parts.joined(separator: " ")
    guard !base.isEmpty else { return "" }

    let locale = Locale(identifier: "en_US_POSIX")
    let folded = base
        .applyingTransform(.toLatin, reverse: false)?
        .applyingTransform(.stripCombiningMarks, reverse: false)?
        .folding(options: [.diacriticInsensitive, .widthInsensitive, .caseInsensitive], locale: locale) ?? base

    let tokens = folded
        .lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { !$0.isEmpty }

    guard !tokens.isEmpty else { return "" }

    var slug = ""
    for token in tokens {
        if slug.isEmpty {
            let trimmedToken = String(token.prefix(60))
            slug = trimmedToken
        } else {
            let spaceForToken = 60 - slug.count - 1
            guard spaceForToken > 0 else { break }
            let trimmedToken = String(token.prefix(spaceForToken))
            if !trimmedToken.isEmpty {
                slug += "-\(trimmedToken)"
            }
        }
        if slug.count >= 60 { break }
    }

    while slug.last == "-" {
        slug.removeLast()
    }

    return slug
}

func validateMacros(netCarbsPer100g: Double, protein: Double, fat: Double) -> Bool {
    let macros = [netCarbsPer100g, protein, fat]
    guard macros.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }

    let maxMacro: Double = 1_000 // generous guardrail to prevent absurd label data
    guard macros.allSatisfy({ $0 <= maxMacro }) else { return false }

    return true
}

func per100g(fromServing value: Double, unit: String, carbs: Double, protein: Double, fat: Double) throws -> (Double, Double, Double) {
    guard value.isFinite, value > 0 else {
        throw FoodValidationError.invalidServing
    }

    let normalizedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard let grams = servingInGrams(value: value, unit: normalizedUnit) else {
        throw FoodValidationError.invalidServing
    }

    let scale = 100.0 / grams
    return (carbs * scale, protein * scale, fat * scale)
}

func servingInGrams(value: Double, unit: String) -> Double? {
    switch unit {
    case "g", "gram", "grams":
        return value
    case "kg", "kilogram", "kilograms":
        return value * 1_000.0
    case "mg", "milligram", "milligrams":
        return value / 1_000.0
    case "lb", "lbs", "pound", "pounds":
        return value * 453.59237
    case "oz", "ounce", "ounces":
        return value * 28.3495231
    case "ml", "milliliter", "milliliters":
        return value // assume 1 ml ~= 1 g, caller should adjust when density differs
    case "l", "liter", "liters":
        return value * 1_000.0
    case "":
        return value
    default:
        return nil
    }
}
