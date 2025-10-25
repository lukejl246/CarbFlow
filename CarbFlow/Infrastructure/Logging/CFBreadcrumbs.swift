import Foundation

struct CFBreadcrumb {
    enum Kind: String {
        case screen
        case action
        case network
        case system
    }

    let kind: Kind
    let label: String
    let data: [String: Any]?
    let timestamp: Date
}

final class CFBreadcrumbsStore {
    static let shared = CFBreadcrumbsStore()

    private let queue = DispatchQueue(label: "com.carbflow.breadcrumbs", qos: .utility)
    private var items: [CFBreadcrumb] = []
    private let capacity: Int = 50

    private init() { }

    func add(_ breadcrumb: CFBreadcrumb) {
        queue.async { [weak self] in
            guard let self else { return }
            var updated = self.items
            updated.append(breadcrumb)
            if updated.count > self.capacity {
                updated.removeFirst(updated.count - self.capacity)
            }
            self.items = updated

            let payloads = updated.map { item -> [String: Any] in
                var payload: [String: Any] = [
                    "kind": item.kind.rawValue,
                    "label": item.label,
                    "ts": Int(item.timestamp.timeIntervalSince1970)
                ]
                if let data = item.data {
                    payload["data"] = cf_redactContext(data)
                }
                return payload
            }
            CFErrorReportingRouter.shared.updateBreadcrumbs(payloads)
        }
    }

    func snapshot(completion: @escaping ([CFBreadcrumb]) -> Void) {
        queue.async { [weak self] in
            completion(self?.items ?? [])
        }
    }
}

func cf_addBreadcrumb(kind: CFBreadcrumb.Kind,
                      label: String,
                      data: [String: Any]? = nil) {
    let breadcrumb = CFBreadcrumb(kind: kind, label: label, data: data, timestamp: Date())
    CFBreadcrumbsStore.shared.add(breadcrumb)
}

func cf_breadcrumbScreen(_ name: String) {
    cf_addBreadcrumb(kind: .screen, label: name)
}

func cf_breadcrumbAction(_ name: String, data: [String: Any]? = nil) {
    cf_addBreadcrumb(kind: .action, label: name, data: data)
}
