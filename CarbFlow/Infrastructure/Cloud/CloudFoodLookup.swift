import Foundation

enum CloudFoodLookupResult {
    case notImplemented
}

protocol CloudFoodLookupServicing {
    func lookup(upc: String) async -> CloudFoodLookupResult
}

struct CloudFoodLookup: CloudFoodLookupServicing {
    func lookup(upc: String) async -> CloudFoodLookupResult {
        #if DEBUG
        print("[CloudFoodLookup] Stub lookup for UPC \(upc)")
        #endif
        return .notImplemented
    }
}
