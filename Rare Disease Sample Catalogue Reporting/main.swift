//
//  main.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

class Runner {
    var result: [URL: Int]
    var ols: OntologyLookupService
    var samples: Samples
    private let diseaseGroup: URL = "http://www.orpha.net/ORDO/Orphanet_377794"
    init() {
        let group = DispatchGroup()
        samples = Samples(group)
        ols = OntologyLookupService(group)
        result = [URL: Int]()
        group.wait()
    }

    func run() {
        ols.depthFirstSearch(starting: diseaseGroup, direction: .incoming) { (edge) -> Bool in
            result[edge.source] = 0
            return false
        }

        samples.aggregates.forEach { (disease, count) in
            ols.depthFirstSearch(starting: disease, direction: .outgoing) { (edge) -> Bool in
                if edge.target == diseaseGroup {
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
print(runner.result.map({ (group, count) -> String in
    return "\(runner.ols.findVertex(with: group)?.label ?? "")\t\(group.lastPathComponent)\t\(count)"
}))

