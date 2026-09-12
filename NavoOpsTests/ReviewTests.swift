import XCTest
@testable import NavoOps

final class ReviewTests: XCTestCase {
    func testAppleUnresolvedReviewRequiresAction() throws {
        let json = """
        {
          "schemaVersion": 2,
          "generatedAt": "2026-09-12T07:43:22Z",
          "sourceRepository": "acciento89-bot/onemorefloor",
          "appleAvailable": true,
          "googleAvailable": false,
          "apps": [{
            "provider": "apple",
            "appName": "RohrCalc",
            "externalID": "6804748249",
            "bundleOrPackageID": "de.kamilunavo.rohrcalc",
            "version": "1.0",
            "build": "5",
            "rawState": "REJECTED",
            "state": "rejected",
            "updatedAt": "2026-09-12T07:40:00Z",
            "detail": "UNRESOLVED_ISSUES · REJECTED",
            "review": {
              "submissionID": "submission-1",
              "submissionState": "UNRESOLVED_ISSUES",
              "itemStates": ["REJECTED"],
              "submittedAt": "2026-09-12T07:39:00Z",
              "track": null,
              "lifecycleState": null,
              "reason": null,
              "reasonAvailability": "consoleOnly",
              "consoleURL": "https://appstoreconnect.apple.com/apps/6804748249"
            }
          }]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let feed = try decoder.decode(StoreStatusFeed.self, from: Data(json.utf8))
        let snapshot = try XCTUnwrap(feed.apps.first)

        XCTAssertEqual(snapshot.provider, .apple)
        XCTAssertEqual(snapshot.state, .rejected)
        XCTAssertEqual(snapshot.review?.submissionState, "UNRESOLVED_ISSUES")
        XCTAssertEqual(snapshot.review?.itemStates, ["REJECTED"])
        XCTAssertTrue(snapshot.review?.requiresAction == true)
        XCTAssertEqual(snapshot.review?.reasonAvailability, .consoleOnly)
    }

    func testGoogleNotApprovedReviewRequiresAction() throws {
        let review = StoreReviewSnapshot(
            track: "production",
            lifecycleState: "RELEASE_LIFECYCLE_STATE_NOT_APPROVED",
            reasonAvailability: .consoleOnly,
            consoleURL: "https://play.google.com/console"
        )

        XCTAssertTrue(review.requiresAction)
        XCTAssertEqual(review.displayState, "RELEASE_LIFECYCLE_STATE_NOT_APPROVED")
    }

    func testLegacyStoreFeedWithoutReviewStillDecodes() throws {
        let json = """
        {
          "schemaVersion": 1,
          "generatedAt": "2026-09-11T16:20:31Z",
          "sourceRepository": "legacy",
          "appleAvailable": true,
          "googleAvailable": false,
          "apps": [{
            "provider": "apple",
            "appName": "NavoOps",
            "externalID": "6811085573",
            "bundleOrPackageID": "com.kamilunavo.NavoOps",
            "version": "1.3.0",
            "build": "4",
            "rawState": "WAITING_FOR_REVIEW",
            "state": "review",
            "updatedAt": "2026-09-11T21:21:59Z",
            "detail": "WAITING_FOR_REVIEW"
          }]
        }
        """

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let feed = try decoder.decode(StoreStatusFeed.self, from: Data(json.utf8))
        XCTAssertNil(feed.apps.first?.review)
    }

    func testGuidelineExtractionFindsUniqueCodes() {
        let text = "Guideline 4.3(a) - Design. Also see 2.1 and guideline 4.3(a)."
        XCTAssertEqual(ReviewNoteStore.tags(in: text), ["2.1", "4.3(a)"])
    }

    func testReviewNotesPersistOnlyInProvidedLocalDefaults() throws {
        let suiteName = "NavoOpsTests.ReviewNotes.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ReviewNoteStore(defaults: defaults)
        let note = ReviewNote(snapshotID: "apple:123", message: "Guideline 4.3(a)", tags: ["4.3(a)"], updatedAt: .now)
        store.save([note.snapshotID: note])

        XCTAssertEqual(store.load()[note.snapshotID]?.message, "Guideline 4.3(a)")
        XCTAssertEqual(store.load()[note.snapshotID]?.tags, ["4.3(a)"])
    }
}
