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


import Foundation

enum ORDO: String {
    case groupOfDisorders = "http://www.orpha.net/ORDO/Orphanet_557492"
    case disorder = "http://www.orpha.net/ORDO/Orphanet_557493"
    case subClassOf = "http://www.w3.org/2000/01/rdf-schema#subClassOf"
    case partOf = "http://www.orpha.net/ORDO/Orphanet_C021"
    case obsoleteDisorder = "http://www.orpha.net/ORDO/Orphanet_C052"
    case nonRareDisorder = "http://www.orpha.net/ORDO/Orphanet_C048"
    case clinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C001"
    case obsoleteClinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C050"
    case nonRareClinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C046"
    case deprecatedClinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C042"
    case inActiveClinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C041"
    
    static let relations = [
        subClassOf, partOf
    ].map { $0.rawValue }
    static let terminalNodes = [
        clinicalEntity, inActiveClinicalEntity
    ].map { $0.rawValue }
    static let inactive = [
        deprecatedClinicalEntity, obsoleteClinicalEntity, nonRareClinicalEntity
    ].map { $0.rawValue }

    static func isSubClassOrPartOfRelationship(edge: Edge) -> Bool {
        return ORDO.relations.contains(edge.predicate)
    }


    static func isMainCategory(node: [Edge]) -> Bool {
        guard !node.isEmpty else { return false }
        if inactive.contains(node[0].subject) {
            return true
        }
        guard node.contains(where: { ORDO.groupOfDisorders.rawValue == $0.object.value }) else { return false }

        let subclass = node.filter { $0.predicate == ORDO.subClassOf.rawValue }
        let isMatch = subclass.map({ $0.object.value }).filter({ isNotATerminalNode(value: $0) }).isEmpty
        return isMatch
    }

    static func isNotATerminalNode(value: String) -> Bool {
        return !terminalNodes.contains(value) && value != groupOfDisorders.rawValue
    }
}
