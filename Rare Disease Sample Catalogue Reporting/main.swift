//
//  main.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

class Runner {
    var result: [URL: Int]!
    var ols: OntologyLookupService
    var samples: Samples

    init() {
        samples = Samples()
        samples.ready.wait()
        ols = OntologyLookupService()
        ols.ready.wait()
    }

    func run() {
        let groups = ols.edges.filter { (vertex) -> Bool in
            return vertex.target == "http://www.orpha.net/ORDO/Orphanet_377794"
            }.map { return $0.source }

        result = Dictionary(uniqueKeysWithValues: zip(groups, Array(repeating: 0, count: groups.count)))

        samples.aggregates.forEach { (disease, count) in

            ols.depthFirstSearch(starting: disease) { (edge) -> Bool in
                if edge.target == "http://www.orpha.net/ORDO/Orphanet_377794" {
                    print("\(disease) \(edge.source) \(count)")
                    self.result[edge.source] = (self.result[edge.source] ?? 0) + count
                    return false
                }
                return true
            }
        }
    }
}

let runner = Runner()
runner.run()
print(runner.result!.map({ (group, count) -> String in
    return "\(runner.ols.findVertex(with: group)?.label ?? "")\t\(group)\t\(count)"
}))

