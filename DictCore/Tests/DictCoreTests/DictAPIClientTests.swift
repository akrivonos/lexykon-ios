import XCTest
@testable import DictCore

final class DictAPIClientTests: XCTestCase {

    func testErrorEnvelopeDecoding() {
        let json = """
        {"error":{"code":"NOT_FOUND","message":"Entry not found","details":[],"request_id":"abc-123"}}
        """
        let data = json.data(using: .utf8)!
        let error = DictAPIError.from(data: data)
        XCTAssertNotNil(error)
        XCTAssertEqual(error?.code, "NOT_FOUND")
        XCTAssertEqual(error?.message, "Entry not found")
    }

    func testAutocompleteItemDecoding() {
        let json = """
        {"lemma_id":"uuid","lemma":"говорити","headword_stressed":"говори́ти","pos":"verb","stress_forms":[{"stressed_form":"говори́ти","is_primary":true}],"frequency_rank":"100"}
        """
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let item = try? decoder.decode(AutocompleteItem.self, from: data)
        XCTAssertNotNil(item)
        XCTAssertEqual(item?.lemma, "говорити")
        XCTAssertEqual(item?.headwordStressed, "говори́ти")
        XCTAssertEqual(item?.pos, "verb")
        XCTAssertEqual(item?.primaryStressed, "говори́ти")
    }

    func testLookupResponseAlsoFoundDecoding() throws {
        let json = """
        {"query":"a","match_type":"exact","entry":null,"also_found":[{"entry_id":"e1","headword":"біг","pos":"noun","slug":"bih","content_tier":"bronze"}],"fuzzy_suggestions":[],"reverse_results":[]}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let r = try decoder.decode(LookupResponse.self, from: Data(json.utf8))
        XCTAssertEqual(r.alsoFound?.count, 1)
        XCTAssertEqual(r.alsoFound?.first?.slug, "bih")
    }
}
