import XCTest
@testable import Catchable

final class ServiceNoticeTests: XCTestCase {
    func testMalformedOptionalRemarkDoesNotDiscardDepartures() throws {
        let data = Data(#"{"departures":[{"tripId":"one","direction":"Warschauer Straße","remarks":[null,42,{"type":"warning","id":123,"summary":"Bauarbeiten","text":{"unexpected":true}}]}]}"#.utf8)
        let board = try JSONDecoder().decode(TransportBoard.self, from: data)
        XCTAssertEqual(board.departures.count, 1)
        XCTAssertEqual(board.departures[0].remarks?.compactMap(\.noticeText), ["Bauarbeiten"])
        XCTAssertEqual(board.departures[0].remarks?.last?.id, "123")
    }

    func testRemarksDecodeGermanWarningAndRemoveRoutineMetadata() throws {
        let data = Data(#"{"departures":[{"tripId":"one","direction":"Warschauer Straße","line":{"name":"M10","product":"tram"},"plannedWhen":"2026-10-14T12:00:00+02:00","remarks":[{"type":"warning","id":"closure","summary":"Bauarbeiten","text":"<p>Halt entfällt &amp; Ersatzverkehr.</p>"},{"type":"hint","code":"OPERATOR","text":"BVG"},{"type":"hint","code":"text.occup.loc.max.11","text":"low occupancy expected"}]}]}"#.utf8)
        let board = try JSONDecoder().decode(TransportBoard.self, from: data)
        let remarks = try XCTUnwrap(board.departures.first?.remarks)
        XCTAssertEqual(remarks.compactMap(\.noticeText), ["Halt entfällt & Ersatzverkehr."])
        XCTAssertEqual(TransportRemark(type: "warning", summary: "Nur Zusammenfassung").noticeText, "Nur Zusammenfassung")
        XCTAssertNil(TransportRemark(type: "warning", text: "  ").noticeText)
    }

    func testProviderNoticesAreDeduplicatedAndRestrictedToSavedDirection() async throws {
        let remark = TransportRemark(id: "warning", type: "warning", text: "Halt entfällt")
        let selected = TransportDeparture(tripId: "one", direction: "Warschauer Straße",
            line: .init(id: "route", name: "M10", product: "tram"), when: nil,
            plannedWhen: "2026-10-14T12:00:00+02:00", cancelled: true, delay: nil, remarks: [remark])
        let opposite = TransportDeparture(tripId: "two", direction: "Hauptbahnhof",
            line: .init(id: "route", name: "M10", product: "tram"), when: nil,
            plannedWhen: "2026-10-14T12:10:00+02:00", cancelled: false, delay: nil,
            remarks: [TransportRemark(type: "warning", text: "Other direction only")])
        let service = SavedService(id: "saved", station: "Bersarinplatz", line: "M10", destination: "Warschauer Straße",
            mode: .tram, walkingMinutes: 5, stopID: "900120516", providerLineID: "route")
        let snapshot = try await LiveDepartureProvider(api: NoticeAPI(items: [selected, selected, opposite])).fetchDepartures(for: [service])
        XCTAssertEqual(snapshot.notices?.map(\.text), ["Halt entfällt"])
        XCTAssertEqual(snapshot.notices?.first?.serviceID, service.id)
        let decoded = try JSONDecoder().decode(DepartureSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.notices, snapshot.notices)
    }

    @MainActor func testInfoOnlyContainsNoticesForStationsInCard() {
        let model = NowViewModel(provider: SampleDepartureProvider())
        let service = PlaceStore.sample.services[0]
        model.snapshot = DepartureSnapshot(departures: [], fetchedAt: Date(), isSample: false, notices: [
            ServiceNotice(id: "1", serviceID: service.id, text: "Notice", kind: "warning"),
            ServiceNotice(id: "2", serviceID: service.id, text: "Notice", kind: "warning"),
            ServiceNotice(id: "3", serviceID: "other", text: "Unrelated", kind: "warning")
        ])
        XCTAssertEqual(model.notices(for: [service]).map(\.text), ["Notice"])
        XCTAssertTrue(model.notices(for: []).isEmpty)
    }
}

private struct NoticeAPI: TransitAPI {
    let items: [TransportDeparture]
    func searchStops(_ query: String) async throws -> [TransportStop] { [] }
    func board(stopID: String, minutes: Int) async throws -> TransportBoard { TransportBoard(departures: items) }
}
