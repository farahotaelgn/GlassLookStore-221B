import Foundation

/// Commits and lines changed today from the GitHub REST API (token in the Keychain, repo "owner/name" in Settings).
/// Session, usage, tokens, builds and streak come from the Mock source until a real source exists for them.
@MainActor
final class GitHubProvider: CounterProvider {
    let name = "GitHub"
    static let repoKey = "github.repo"

    enum Status: Equatable { case notAdded, working, notWorking(String) }

    private let fallback = MockProvider()
    private var cache: CommitInfo?
    private var lastFetch: Date?
    private var fetching = false
    private(set) var status: Status = .notAdded

    var repo: String { UserDefaults.standard.string(forKey: Self.repoKey) ?? "" }

    func session(now: Date) -> SessionInfo {
        var s = fallback.session(now: now)
        s.project = repo.split(separator: "/").last.map(String.init) ?? s.project
        s.status = "GitHub, session live"
        return s
    }

    func usage(now: Date) -> UsageInfo { fallback.usage(now: now) }
    func tokens(now: Date) -> Int { fallback.tokens(now: now) }
    func builds(now: Date) -> BuildInfo { fallback.builds(now: now) }
    func streak(now: Date) -> Int { fallback.streak(now: now) }

    func commits(now: Date) async -> CommitInfo {
        if lastFetch.map({ now.timeIntervalSince($0) > 300 }) ?? true, !fetching {
            await refresh(now: now)
        }
        return cache ?? fallback.commits(now: now)
    }

    /// Asks GitHub again (Settings › 🧪 Test key, and every 5 minutes while the app is open).
    func refresh(now: Date = .now) async {
        guard let token = KeychainStore.read(KeychainStore.githubToken), !token.isEmpty else { status = .notAdded; return }
        let parts = repo.split(separator: "/")
        guard parts.count == 2 else { status = .notWorking("Repo must look like owner/name"); return }
        fetching = true
        defer { fetching = false; lastFetch = now }
        let since = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: now))
        do {
            let list: [CommitRef] = try await get("https://api.github.com/repos/\(repo)/commits?since=\(since)&per_page=30", token: token)
            var added = 0, removed = 0
            for ref in list.prefix(10) {
                let detail: CommitDetail = try await get("https://api.github.com/repos/\(repo)/commits/\(ref.sha)", token: token)
                added += detail.stats?.additions ?? 0
                removed += detail.stats?.deletions ?? 0
            }
            cache = CommitInfo(today: list.count, added: added, removed: removed)
            status = .working
        } catch {
            status = .notWorking(error.localizedDescription)
        }
    }

    private struct CommitRef: Decodable, Sendable { let sha: String }
    private struct CommitDetail: Decodable, Sendable { struct Stats: Decodable, Sendable { let additions: Int; let deletions: Int }; let stats: Stats? }

    private struct HTTPError: LocalizedError { let code: Int; var errorDescription: String? { "GitHub answered \(code)" } }

    private func get<T: Decodable & Sendable>(_ url: String, token: String) async throws -> T {
        guard let u = URL(string: url) else { throw URLError(.badURL) }
        var r = URLRequest(url: u)
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        r.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        let (data, response) = try await URLSession.shared.data(for: r)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw HTTPError(code: http.statusCode) }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
