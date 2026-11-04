//
//  DustinHealthSource.swift
//  Bullet Tracker
//
//  bt-0019 (Step 3 of the dh → Bullet sync). The real `HabitFactsSource`
//  over dustin-health's app endpoint (`api/bullet.js`, dh-0014):
//
//    POST ?op=sync      habits + targets + time zone + today's hand ticks
//    GET  ?op=changes   days whose facts changed since a cursor
//    GET  ?op=facts     meal totals + workout minutes per local day
//    GET  ?op=inbox     voice actions waiting (marks them fetched)
//    POST ?op=ack       ids the app actually applied
//
//  The key travels in the Authorization header only, never in a URL, and
//  lives in the iOS Keychain on this device only (`APIKeyStore`). dh never
//  grades; everything that comes back is numbers and intents, turned into
//  the app's own types here. One-way: nothing in this file reads iCloud.
//

import Foundation
import Security

// MARK: - Key store (iOS Keychain)

/// The app's key to dh. Pasted once in Settings on the iPhone, trimmed
/// (dh's own smoke check failed on a trailing line break), and stored as a
/// generic password that never leaves this device: not iCloud Keychain, not
/// a backup restored onto another device. Never logged, never in the build.
enum APIKeyStore {
    static let service = "com.dustin.bullet-tracker.dustin-health"
    static let account = "bullet-api-key"

    enum StoreError: LocalizedError {
        case empty
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case .empty: return "The key is empty."
            case .keychain(let status): return "Keychain error \(status)."
            }
        }
    }

    /// What Save actually stores: whitespace and line breaks stripped from
    /// both ends. `nil` when nothing is left.
    static func trimmed(_ pasted: String) -> String? {
        let cleaned = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private static var baseQuery: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    static func read() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasKey: Bool { read() != nil }

    /// Replaces any stored key. Throws `.empty` when the trimmed paste is blank.
    static func save(_ pasted: String) throws {
        guard let key = trimmed(pasted), let data = key.data(using: .utf8) else { throw StoreError.empty }
        SecItemDelete(baseQuery as CFDictionary)
        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw StoreError.keychain(status) }
    }

    static func delete() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    /// For the Developer readout: the stored item's accessibility class, so
    /// "this device only" is shown, not claimed.
    static var accessibilityDescription: String? {
        var query = baseQuery
        query[kSecReturnAttributes as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let attributes = item as? [String: Any],
              let accessible = attributes[kSecAttrAccessible as String] as? String else { return nil }
        if accessible == (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String) {
            return "this device only"
        }
        return accessible
    }
}

// MARK: - Client (the five ops)

struct DustinHealthClient: Sendable {
    static let defaultBaseURL = URL(string: "https://yuelxxoophskfmadcjng.supabase.co/functions/v1/bullet")!

    enum ClientError: LocalizedError, Equatable {
        /// 401 — the key is wrong (or not set on dh).
        case unauthorized
        /// 400 — the app sent something dh's validator rejected.
        case badRequest(String)
        /// 422 — the database said no (a duplicate name, a target out of range).
        case rejected(String)
        case unknownOperation
        case http(Int)
        case badResponse

        var errorDescription: String? {
            switch self {
            case .unauthorized: return "Key rejected"
            case .badRequest(let message): return "dh refused the request: \(message)"
            case .rejected(let message): return "dh rejected it: \(message)"
            case .unknownOperation: return "dh doesn't know that operation"
            case .http(let code): return "dh answered \(code)"
            case .badResponse: return "dh's answer couldn't be read"
            }
        }

        /// True for a key problem, so Settings can say so plainly.
        var isAuthFailure: Bool { self == .unauthorized }
    }

    let key: String
    var baseURL: URL = DustinHealthClient.defaultBaseURL
    var session: URLSession = .shared
    var timeout: TimeInterval = 15

    // MARK: Wire types (dh's JSON, verbatim field names)

    struct SyncRequest: Encodable {
        struct HabitItem: Encodable {
            let name: String
            let kind: String
            let detail_kind: String?
            enum CodingKeys: String, CodingKey { case name, kind, detail_kind }
            // Encode `detail_kind: null` explicitly so dh clears a stale value.
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CodingKeys.self)
                try c.encode(name, forKey: .name)
                try c.encode(kind, forKey: .kind)
                try c.encode(detail_kind, forKey: .detail_kind)
            }
        }
        let habits: [HabitItem]
        let targets: [String: Double]
        let time_zone: String
        /// 2026-10-30 — "YYYY-MM-DD" (the app's local day) → habit names,
        /// the last seven days with empty lists for quiet days. Replaced
        /// `ticked_today` (today's list alone) once dh's per-day side went
        /// live the same day (dh-0023).
        let ticked_days: [String: [String]]
    }

    struct SyncResponse: Decodable {
        let habits: Int?
        let held_targets: [String]?
        let targets: [String: Double]?
        let time_zone: String?
        /// Tick days dh refused (future, > 14 days old, malformed). The sync
        /// still succeeds; the app shows them as a problem.
        let skipped_days: [String]?
    }

    struct ChangesResponse: Decodable {
        let days: [String]
        let next_since: String
    }

    struct FactsResponse: Decodable {
        struct Meals: Decodable {
            /// One meal (bt-0021). dh sends `null` for a number it doesn't know.
            struct Item: Decodable {
                let id: String?
                let name: String?
                let calories: Double?
                let protein: Double?
                let carbs: Double?
                let fat: Double?
                let logged_at: String?
            }
            let count: Double?
            let calories: Double?
            let protein: Double?
            let names: [String]?
            let items: [Item]?
        }
        struct Session: Decodable {
            let name: String?
            let minutes: Double?
            let category: String?
            let set_count: Int?
            let started_at: String?
            // bt-0022 (dh b7d3b5c). `activity_code` is decoded so an
            // unknown shape never fails the row, but not used: it is on
            // only 24 of 141 sessions since Aug 1.
            let active_kcal: Double?
            let activity_type: String?
            let activity_code: Int?
        }
        struct Workouts: Decodable {
            let count: Double?
            let minutes: Double?
            let sessions: [Session]?
        }
        struct Day: Decodable {
            let day: String
            let meals: Meals?
            let workouts: Workouts?
        }
        let time_zone: String?
        let days: [Day]
    }

    struct InboxResponse: Decodable {
        struct Row: Decodable {
            let id: String
            let habit: String?
            let kind: String?
            let day: String
            let action: String
            let grade: String?
            let note: String?
            let book: String?
            let pages: Int?
            let target_key: String?
            let target_value: Double?
        }
        let actions: [Row]
    }

    struct AckRequest: Encodable {
        let ids: [String]
    }

    struct AckResponse: Decodable {
        struct NotApplied: Decodable {
            let id: String
            let reason: String
        }
        let applied: Int
        let not_applied: [NotApplied]?
    }

    struct ErrorBody: Decodable {
        let error: String?
        let message: String?
    }

    // MARK: Calls

    func sync(_ body: SyncRequest) async throws -> SyncResponse {
        try await send(op: "sync", method: "POST", body: body)
    }

    func changes(since: String) async throws -> ChangesResponse {
        try await send(op: "changes", query: [URLQueryItem(name: "since", value: since)])
    }

    func facts(from: String, to: String) async throws -> FactsResponse {
        try await send(op: "facts", query: [URLQueryItem(name: "from", value: from), URLQueryItem(name: "to", value: to)])
    }

    func inbox() async throws -> InboxResponse {
        try await send(op: "inbox")
    }

    func ack(ids: [String]) async throws -> AckResponse {
        try await send(op: "ack", method: "POST", body: AckRequest(ids: ids))
    }

    // MARK: Transport

    private struct NoBody: Encodable {}

    private func send<T: Decodable>(op: String, method: String = "GET", query: [URLQueryItem] = []) async throws -> T {
        try await send(op: op, method: method, query: query, body: Optional<NoBody>.none)
    }

    /// The request URL. `URLComponents` leaves "+" unescaped in a query,
    /// and dh's server reads an unescaped "+" as a space — so the cursor
    /// `2026-10-27T17:58:12+00:00` arrived as `…12 00:00` and dh refused it
    /// ("since must be an ISO timestamp", found in the bt-0019 pass test).
    /// Every "+" is sent as %2B so it comes back out as "+".
    static func url(base: URL, op: String, query: [URLQueryItem]) -> URL? {
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "op", value: op)] + query
        let encoded = components?.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components?.percentEncodedQuery = encoded
        return components?.url
    }

    private func send<T: Decodable, B: Encodable>(op: String, method: String, query: [URLQueryItem] = [], body: B?) async throws -> T {
        guard let url = Self.url(base: baseURL, op: op, query: query) else { throw ClientError.badResponse }

        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.badResponse }
        switch http.statusCode {
        case 200:
            do { return try JSONDecoder().decode(T.self, from: data) } catch { throw ClientError.badResponse }
        case 401:
            throw ClientError.unauthorized
        case 400:
            throw ClientError.badRequest(Self.message(in: data))
        case 404:
            throw ClientError.unknownOperation
        case 422:
            throw ClientError.rejected(Self.message(in: data))
        default:
            throw ClientError.http(http.statusCode)
        }
    }

    private static func message(in data: Data) -> String {
        (try? JSONDecoder().decode(ErrorBody.self, from: data))?.message ?? "no detail"
    }
}

// MARK: - Wire ⇄ app types

/// Pure conversions between dh's JSON shapes and the app's `Sync` types.
/// Kept as static functions so they are unit-testable without a network.
enum DustinHealthWire {
    /// "YYYY-MM-DD" → start of that local day. dh already works in the time
    /// zone the app sent, so the day string IS his day.
    static func day(from string: String, calendar: Calendar = .current) -> Date? {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    /// Start of a local day → "YYYY-MM-DD".
    static func string(from day: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func syncRequest(_ payload: HabitSyncPayload) -> DustinHealthClient.SyncRequest {
        DustinHealthClient.SyncRequest(
            habits: payload.habits.map { .init(name: $0.name, kind: $0.kind, detail_kind: $0.detailKind) },
            targets: Dictionary(uniqueKeysWithValues: payload.targets.map { ($0.key.rawValue, $0.value) }),
            time_zone: payload.timeZone,
            ticked_days: Dictionary(uniqueKeysWithValues: payload.tickedDays.map { (string(from: $0.key), $0.value) })
        )
    }

    static func syncReply(_ response: DustinHealthClient.SyncResponse) -> HabitSyncReply {
        let held = (response.held_targets ?? []).compactMap(TargetKey.init(rawValue:))
        var targets: [TargetKey: Double] = [:]
        for (key, value) in response.targets ?? [:] {
            if let typed = TargetKey(rawValue: key) { targets[typed] = value }
        }
        return HabitSyncReply(heldTargets: held, targets: targets, skippedDays: response.skipped_days ?? [])
    }

    static func changedDays(_ response: DustinHealthClient.ChangesResponse, calendar: Calendar = .current) -> ChangedDays {
        ChangedDays(days: response.days.compactMap { day(from: $0, calendar: calendar) }, nextSince: response.next_since)
    }

    static func facts(_ response: DustinHealthClient.FactsResponse, calendar: Calendar = .current) -> [Date: DayFacts] {
        var result: [Date: DayFacts] = [:]
        for row in response.days {
            guard let day = day(from: row.day, calendar: calendar) else { continue }
            let meals = row.meals
            let workouts = row.workouts
            // A day with no meals logged is "nothing tracked" (nil), which
            // the Diet rule grades as a miss — same as dh's zeros, but the
            // caption can tell "nothing yet" from "0 g".
            let tracked = (meals?.count ?? 0) > 0
            result[day] = DayFacts(
                day: day,
                proteinGrams: tracked ? (meals?.protein ?? 0) : nil,
                calories: tracked ? (meals?.calories ?? 0) : nil,
                workoutMinutes: workouts?.minutes ?? 0,
                mealNames: meals?.names ?? [],
                sessions: (workouts?.sessions ?? []).compactMap { s in
                    guard let name = s.name else { return nil }
                    return DayFacts.Session(name: name, minutes: s.minutes ?? 0, category: s.category,
                                            setCount: s.set_count ?? 0, startedAt: timestamp(from: s.started_at),
                                            activeKcal: s.active_kcal, activityType: s.activity_type)
                },
                meals: (meals?.items ?? []).compactMap { m in
                    guard let name = m.name else { return nil }
                    return DayFacts.Meal(id: m.id, name: name, calories: m.calories, protein: m.protein,
                                         carbs: m.carbs, fat: m.fat, loggedAt: timestamp(from: m.logged_at))
                }
            )
        }
        return result
    }

    /// dh's timestamps are UTC ISO 8601, with or without fractional seconds
    /// (`2026-10-27T14:05:22.397+00:00` from the meals, `…T15:17:08+00:00`
    /// from the sessions). Read as an instant; shown local by the views.
    static func timestamp(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) { return date }
        return ISO8601DateFormatter().date(from: string)
    }

    static func actions(_ response: DustinHealthClient.InboxResponse, calendar: Calendar = .current) -> [InboxAction] {
        response.actions.compactMap { row in
            guard let day = day(from: row.day, calendar: calendar) else { return nil }
            let kind: InboxAction.Kind
            switch row.action {
            case "tick":
                kind = .tick(note: row.note, book: row.book, pages: row.pages)
            case "untick":
                kind = .untick
            case "set_grade":
                guard let grade = row.grade.flatMap(VoiceGrade.init(rawValue:)) else { return nil }
                kind = .setGrade(grade)
            case "note":
                kind = .note(text: row.note, book: row.book, pages: row.pages)
            case "set_target":
                guard let key = row.target_key.flatMap(TargetKey.init(rawValue:)), let value = row.target_value else { return nil }
                kind = .setTarget(key, value)
            default:
                return nil
            }
            return InboxAction(id: row.id, kind: kind, habitName: row.habit, day: day)
        }
    }

    static func ackResult(_ response: DustinHealthClient.AckResponse) -> AckResult {
        AckResult(applied: response.applied,
                  notApplied: (response.not_applied ?? []).map { .init(id: $0.id, reason: $0.reason) })
    }

    /// Splits a set of days into inclusive ranges dh accepts: contiguous
    /// runs, each at most `maxDays` long (dh caps a facts call at 93).
    static func ranges(of days: Set<Date>, maxDays: Int = 93, calendar: Calendar = .current) -> [(from: Date, to: Date)] {
        let sorted = days.map { calendar.startOfDay(for: $0) }.sorted()
        var result: [(Date, Date)] = []
        var start: Date?
        var end: Date?
        for day in sorted {
            if let s = start, let e = end,
               let next = calendar.date(byAdding: .day, value: 1, to: e), next == day,
               (calendar.dateComponents([.day], from: s, to: day).day ?? 0) < maxDays - 1 {
                end = day
            } else {
                if let s = start, let e = end { result.append((s, e)) }
                start = day
                end = day
            }
        }
        if let s = start, let e = end { result.append((s, e)) }
        return result.map { (from: $0.0, to: $0.1) }
    }
}

// MARK: - The source

struct DustinHealthFacts: HabitFactsSource {
    let client: DustinHealthClient
    let displayName = "Dustin's Health"
    let isLive = true

    init(key: String) {
        client = DustinHealthClient(key: key)
    }

    init(client: DustinHealthClient) {
        self.client = client
    }

    func sync(_ payload: HabitSyncPayload) async throws -> HabitSyncReply {
        DustinHealthWire.syncReply(try await client.sync(DustinHealthWire.syncRequest(payload)))
    }

    func changedDays(since: String?) async throws -> ChangedDays {
        guard let since else { return ChangedDays(days: [], nextSince: Self.isoNow()) }
        return DustinHealthWire.changedDays(try await client.changes(since: since))
    }

    func facts(from: Date, to: Date) async throws -> [Date: DayFacts] {
        DustinHealthWire.facts(try await client.facts(from: DustinHealthWire.string(from: from),
                                                      to: DustinHealthWire.string(from: to)))
    }

    func pendingActions() async throws -> [InboxAction] {
        DustinHealthWire.actions(try await client.inbox())
    }

    func confirmApplied(_ ids: [String]) async throws -> AckResult {
        guard !ids.isEmpty else { return AckResult(applied: 0, notApplied: []) }
        return DustinHealthWire.ackResult(try await client.ack(ids: ids))
    }

    /// The cursor for a first run: "now", so the next run asks for changes
    /// from here. (The regular window covers the recent days anyway.)
    private static func isoNow() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
