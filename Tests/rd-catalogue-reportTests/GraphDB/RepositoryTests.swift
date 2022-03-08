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
    let disorderGroup = "http://www.orpha.net/ORDO/Orphanet_557492"
    let clinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C001"
    let subClassOf = "http://www.w3.org/2000/01/rdf-schema#subClassOf"
    let relations = [
        "http://www.orpha.net/ORDO/Orphanet_C021", // partOf
        "http://www.w3.org/2000/01/rdf-schema#subClassOf" // subClassOf
    ]
    let repository = Repository(url: URL(string: "http://localhost:7200/")!, repository: "ordo")


    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDepthFirstSearch() async throws {

        let results = try await repository.depthFirstSearch(starting: "http://www.orpha.net/ORDO/Orphanet_85102", direction: .outgoing) {
            relations.contains($0.predicate)
        } isMatch: { edges in
            let groups = edges.filter { disorderGroup == $0.object.value }
            guard !groups.isEmpty else { return false }
            return groups.filter { $0.object.value != clinicalEntity && $0.object.value != disorderGroup }.isEmpty
        }

        XCTAssertTrue(results.count > 0, "Results must be non-empty, actually \(results.count)")
        XCTAssertTrue(results.count == 6, "Expected that this disease is part of seven disease groups, actually \(results.count)")

    }

    func testMatchOnHeadOnly() async throws {

        let results = try await repository.depthFirstSearch(starting: "http://www.orpha.net/ORDO/Orphanet_506207", direction: .outgoing) {
            relations.contains($0.predicate)
        } isMatch: { edges in
            guard edges.contains(where: { disorderGroup == $0.object.value }) else { return false }
            let subclass = edges.filter { $0.predicate == subClassOf }
            let isMatch = subclass.filter { $0.object.value != clinicalEntity && $0.object.value != disorderGroup }.isEmpty
            print(isMatch)
            return isMatch
        }

        XCTAssertTrue(results.count == 1, "Must contain only one result, actually \(results)")
        XCTAssertTrue(results.filter { $0 == "http://www.orpha.net/ORDO/Orphanet_565779" }.isEmpty == false , "Expected that this disease is part of Rare disorder potentially indicated for transplant or complication after transplantation, actually \(results)")

    }

}
