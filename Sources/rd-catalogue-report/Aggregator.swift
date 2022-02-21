//
//  main.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by Esther van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation
import ArgumentParser

@main
struct Aggregator {
    static let diseaseGroup: URL = "http://www.orpha.net/ORDO/Orphanet_557492"
    static let obsoleteGroup: URL = "http://www.orpha.net/ORDO/Orphanet_C051"
    static let deprecatedGroup: URL = "http://www.orpha.net/ORDO/Orphanet_C043"
    static let groups = [diseaseGroup, obsoleteGroup, deprecatedGroup]
    static let relations: [URL] = [
        "http://www.orpha.net/ORDO/Orphanet_C021", // partOf new
        "http://purl.obolibrary.org/obo/BFO_0000050", // partOf old
        "http://www.w3.org/2000/01/rdf-schema#subClassOf" // subClassOf
    ]
    static let sampleCatalogue = SampleCatalogue()
    static let ols = OntologyLookupService()

    actor Statistics {
        var countsPerDiseaseCategory = [URL:Int]()
        var countsPerDisease = [URL:Int]()
        var countsUnclassified = [URL:Int]()

        func updateUnclassified(url: URL, count: Int) {
            countsUnclassified[url, default: 0] += count
        }

        func updateDisease(url: URL, count: Int) {
            countsPerDisease[url, default: 0] += count
        }

        func updateGroup(url: URL, count: Int) {
            countsPerDiseaseCategory[url, default: 0] += count
        }
    }

    enum ValidationError: Error {
        case noData
    }

    private static func printStatistics(data: [URL:Int]) async throws {
        guard data.count > 0 else { throw ValidationError.noData }
        print("\"Name\",\"Code\",\"Count\"")
        for (iri, count) in data.sorted(by: { $0.value > $1.value }) {
            let node = try await ols.node(for: iri)
            print("\"\(node.label)\",\"\(node.iri.lastPathComponent)\",\"\(count)\"")
        }
        print("Total: \(data.values.reduce(0, +))")
    }


    static func main() async throws {
        let statistics = Statistics()

        let aggregates = try await sampleCatalogue.aggregatePerDisease()

        for (counts, disease) in zip(aggregates.matrix, aggregates.xLabels) {

            guard disease.IRI.starts(with: "urn:miriam:orphanet") else { continue }
            guard let count = counts.first else {
                print("No counts for disease \(disease.code)")
                continue
            }
            let diseaseURL = URL(string: "http://www.orpha.net/ORDO/Orphanet_\(disease.code)")!
            await statistics.updateDisease(url: diseaseURL, count: count)
            do {
                let diseaseGroups = try await ols.depthFirstSearch(starting: diseaseURL) { (edge) -> Bool in
                    guard relations.contains(edge.uri) else { return false }
                    return edge.target != diseaseGroup
                } isMatch: { groups.contains($0.target) }
                if diseaseGroups.count == 0 {
                    await statistics.updateUnclassified(url: diseaseURL, count: count)
                } else {
                    for diseaseGroup in diseaseGroups {
                        await statistics.updateGroup(url: diseaseGroup, count: count)
                    }
                }
            } catch {
                print("Failed to traverse ontology starting at \(diseaseURL).")
            }
        }
        do {
            try await printStatistics(data: statistics.countsPerDiseaseCategory)
            print("Diseases: \(await statistics.countsPerDisease.count)")
            print("Unclassified: \(await statistics.countsUnclassified.values.reduce(0, +))")
            for (iri, count) in await statistics.countsUnclassified {
                let node = try await ols.node(for: iri)
                print("\(node.label): \(count)")
            }
        } catch {
            print("Failed to generate statistics")
        }
    }

}

