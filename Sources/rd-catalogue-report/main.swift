//
//  main.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

let task = DispatchGroup()
let updates = DispatchGroup()
let updateQueue = DispatchQueue(label: "Update stats")
let diseaseGroup: URL = "http://www.orpha.net/ORDO/Orphanet_377794"
let partOf: URL = "http://purl.obolibrary.org/obo/BFO_0000050"
let subClassOf: URL = "http://www.w3.org/2000/01/rdf-schema#subClassOf"
let sampleCatalogue = SampleCatalogue()
let ols = OntologyLookupService()
var stats = [URL:Int]()
task.enter()
sampleCatalogue.aggregatePerDisease { (result) in
    defer {
        task.leave()
    }
    switch result {
    case .success(let aggregates):
        for (counts, disease) in zip(aggregates.matrix, aggregates.xLabels) {
            guard disease.IRI.starts(with: "urn:miriam:orphanet") else { continue }
            guard let count = counts.first else {
                print("No counts for disease \(disease.code)")
                continue
            }
            guard let diseaseURL = URL(string: "http://www.orpha.net/ORDO/Orphanet_\(disease.code)") else {
                print("Failed to construct URL")
                continue
            }
            do {
//                print("\(disease.preferredTerm)")
                try ols.depthFirstSearch(starting: diseaseURL) { (edge) -> Bool in
                    guard edge.uri == partOf || edge.uri == subClassOf else { return false }
                    if edge.target == diseaseGroup {
                        updates.enter()
                        updateQueue.async {
//                            print("\(disease.preferredTerm): \(edge.source)")
                            stats[edge.source, default: 0] += count
                            updates.leave()
                        }
                    }
                    return edge.target != diseaseGroup
                }
            } catch {
                print("Failed to traverse ontology.")
            }
        }
        updates.wait()
        print("=== Stats ===")
        print("Group | Code | Count")
        print(":-- | :---:  | ---:")
        stats.sorted { $0.value > $1.value }.forEach { (iri, count) in
            guard let result = try? ols.node(for: iri), let node = result else {
                print("Failed to retrieve node for \(iri)")
                return
            }
            print("\(node.label) | \(node.iri.lastPathComponent) | \(count)")
        }
    case .error(let error):
        fatalError(error.localizedDescription)
    }
}

task.wait()

