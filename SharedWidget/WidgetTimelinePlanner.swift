import Foundation

/// Shared by iPhone and Watch widgets; independent of WidgetKit's scheduling API.
struct WidgetTimelinePlanner {
    struct Frame {
        let date: Date
        let snapshot: DepartureSnapshot?
        let message: String?
    }

    func frames(snapshot: DepartureSnapshot?, message: String?, now: Date) -> [Frame] {
        (0...30).map { minute in
            let date = now.addingTimeInterval(Double(minute) * 60)
            let fresh = snapshot.flatMap {
                date.timeIntervalSince($0.fetchedAt) >= -60 &&
                date.timeIntervalSince($0.fetchedAt) < WidgetDataStore.maximumAge ? $0 : nil
            }
            return Frame(date: date, snapshot: fresh,
                message: fresh == nil ? (message ?? "Open Catchable to refresh") : message)
        }
    }
}
