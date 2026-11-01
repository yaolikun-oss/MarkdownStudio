import Foundation
import Combine

/// Independent sessions retain each tab's WKWebView, history and scroll
/// position while sharing WebKit's ordinary website data store.
@MainActor
final class WebBrowserSessions: ObservableObject {
    @Published private(set) var tabIDs: [UUID] = []
    @Published private(set) var activeID: UUID?
    private var sessions: [UUID: WebBrowserSession] = [:]
    private var observers: [UUID: AnyCancellable] = [:]

    init() { _ = create() }

    var activeSession: WebBrowserSession {
        // Closing the last real browser tab installs a blank idle session.
        sessions[activeID!]!
    }

    @discardableResult func create(url: URL? = nil, id: UUID = UUID()) -> UUID {
        guard sessions[id] == nil else { activeID = id; return id }
        let session = WebBrowserSession()
        if let url { session.open(url) }
        sessions[id] = session
        observers[id] = session.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        tabIDs.append(id)
        activeID = id
        return id
    }

    func session(for id: UUID) -> WebBrowserSession? { sessions[id] }

    func activate(_ id: UUID) {
        guard sessions[id] != nil else { return }
        activeID = id
    }

    func close(_ id: UUID) {
        guard let index = tabIDs.firstIndex(of: id) else { return }
        sessions.removeValue(forKey: id)?.close()
        observers.removeValue(forKey: id)?.cancel()
        tabIDs.remove(at: index)
        if activeID == id {
            activeID = tabIDs.indices.contains(index) ? tabIDs[index] : tabIDs.last
        }
        if tabIDs.isEmpty { _ = create() }
    }
}
