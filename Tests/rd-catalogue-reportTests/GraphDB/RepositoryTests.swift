// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import XCTest
@testable import rd_catalogue_report

class RepositoryTests: XCTestCase {
    let repository = Repository(url: URL(string: "http://localhost:7200/")!, repository: "ordo")
    let disease = "http://www.orpha.net/ORDO/Orphanet_85102"
    let category = "http://www.orpha.net/ORDO/Orphanet_506207"
    let headCategory = "http://www.orpha.net/ORDO/Orphanet_565779"
    let obsoleteDisease = "http://www.orpha.net/ORDO/Orphanet_93956"


    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDiseaseToHead() async throws {

        let results = try await repository.depthFirstSearch(starting: disease, direction: .outgoing, shouldTraverse: ORDO.isSubClassOrPartOfRelationship, isMatch: ORDO.isMainCategory)
        print(results)
        XCTAssertTrue(results.count > 0, "Results must be non-empty, actually \(results.count)")
        XCTAssertTrue(results.count == 2, "Expected that this disease is part of seven disease groups, actually \(results.count)")

    }

    func testGroupOfDisordersToHead() async throws {

        let results = try await repository.depthFirstSearch(starting: category, direction: .outgoing, shouldTraverse: ORDO.isSubClassOrPartOfRelationship, isMatch: ORDO.isMainCategory)

        XCTAssertTrue(results.count == 1, "Must contain only one result, actually \(results)")
        XCTAssertTrue(results.filter { $0 == headCategory }.isEmpty == false , "Expected that this disease is part of Rare disorder potentially indicated for transplant or complication after transplantation, actually \(results)")

    }

    func testObsoleteToHead() async throws {
        let results = try await repository.depthFirstSearch(starting: obsoleteDisease, direction: .outgoing, shouldTraverse: ORDO.isSubClassOrPartOfRelationship, isMatch: ORDO.isMainCategory)

        XCTAssertTrue(results.count == 1, "Must contain only one result, actually \(results)")
        XCTAssertTrue(results.filter { $0 == ORDO.obsoleteClinicalEntity.rawValue }.isEmpty == false , "Expected that this disease is marked as an obsolete disease, actually \(results)")


    }

}
