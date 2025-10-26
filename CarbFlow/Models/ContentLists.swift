import Foundation
import Combine

struct ContentList: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let items: [String]
}

@MainActor
final class ContentListStore: ObservableObject {
    @Published private(set) var lists: [String: ContentList] = [:]

    init(bundle: Bundle = .main) {
        loadLists(from: bundle)
    }

    func list(with id: String) -> ContentList? {
        lists[id]
    }

    #if DEBUG
    func reload(bundle: Bundle = .main) {
        loadLists(from: bundle)
    }
    #endif

    private func loadLists(from bundle: Bundle) {
        guard let urls = bundle.urls(forResourcesWithExtension: "json", subdirectory: "lists") else {
            lists = [:]
            return
        }

        let decoder = JSONDecoder()
        var loaded: [String: ContentList] = [:]

        for url in urls {
            do {
                let data = try Data(contentsOf: url)
                let list = try decoder.decode(ContentList.self, from: data)
                loaded[list.id] = list
            } catch {
                continue
            }
        }

        lists = loaded
    }
}
