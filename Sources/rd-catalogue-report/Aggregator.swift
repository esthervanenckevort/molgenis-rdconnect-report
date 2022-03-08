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
    static let disorderGroup = "http://www.orpha.net/ORDO/Orphanet_557492"
    static let clinicalEntity = "http://www.orpha.net/ORDO/Orphanet_C001"
    static let subClassOf = "http://www.w3.org/2000/01/rdf-schema#subClassOf"
    static let relations = [
        "http://www.orpha.net/ORDO/Orphanet_C021", // partOf - relation between disease and disorder group
        "http://www.w3.org/2000/01/rdf-schema#subClassOf" // subClassOf
    ]

    static let sampleCatalogue = SampleCatalogue()
    static let ols = Repository(url: URL(string: "http://localhost:7200/")!, repository: "ordo")

    actor Statistics {
        var countsPerDiseaseCategory = [String:Int]()
        var countsPerDisease = [String:Int]()
        var countsUnclassified = [String:Int]()

        func updateUnclassified(url: String, count: Int) {
            countsUnclassified[url, default: 0] += count
        }

        func updateDisease(url: String, count: Int) {
            countsPerDisease[url, default: 0] += count
        }

        func updateGroup(url: String, count: Int) {
            countsPerDiseaseCategory[url, default: 0] += count
        }
    }

    enum ValidationError: Error {
        case noData
    }

    private static func printStatistics(statistics: Statistics) async throws {
        guard await statistics.countsPerDiseaseCategory.count > 0 else { throw ValidationError.noData }
        print("\"Name\",\"Code\",\"Count\"")
        for (iri, count) in await statistics.countsPerDiseaseCategory.sorted(by: { $0.value > $1.value }) {
            let node = try await ols.node(for: iri)
            print("\"\(node.label)\",\"\(node.iri)\",\"\(count)\"")
        }
        print("Total: \(await statistics.countsPerDiseaseCategory.values.reduce(0, +))")
        print("Diseases: \(await statistics.countsPerDisease.count)")
        print("Unclassified: \(await statistics.countsUnclassified.values.reduce(0, +))")
        #if DEBUG
        for (iri, count) in await statistics.countsUnclassified {
            let node = try await ols.node(for: iri)
            print("\(node.label): \(count)")
        }
        #endif
    }


    static func main() async throws {
        do {
            let statistics = Statistics()

            let aggregates = try await sampleCatalogue.aggregatePerDisease()
            print("\(aggregates.xLabels.count) diseases.")

            for (index, (counts, disease)) in zip(aggregates.matrix, aggregates.xLabels).enumerated() {
                #if DEBUG
                if index % 10 == 0 {
                    print("\(index) done")
                }
                #endif
                // We only process those disease codes that are from Orphanet
                guard disease.IRI.starts(with: "urn:miriam:orphanet") else {
                    print("\(disease.code) is not an Orphanet code.")
                    continue
                }

                // Only if there are counts for the disease
                guard let count = counts.first else {
                    #if DEBUG
                    print("No counts for disease \(disease.code)")
                    #endif
                    continue
                }

                let diseaseURL = "http://www.orpha.net/ORDO/Orphanet_\(disease.code)"
                await statistics.updateDisease(url: diseaseURL, count: count)

                let diseaseGroups = try await ols.depthFirstSearch(starting: diseaseURL, direction: .outgoing) {
                    relations.contains($0.predicate)
                } isMatch: { edges in
                    guard edges.contains(where: { disorderGroup == $0.object.value }) else { return false }
                    let subclass = edges.filter { $0.predicate == subClassOf }
                    let isMatch = subclass.filter { $0.object.value != clinicalEntity && $0.object.value != disorderGroup }.isEmpty
                    return isMatch
                }

                if diseaseGroups.count == 0 {
                    #if DEBUG
                    print("\(disease.code) is not classified.")
                    #endif
                    await statistics.updateUnclassified(url: diseaseURL, count: count)
                } else {
                    #if DEBUG
                    print("\(disease.code) is in \(diseaseGroups)")
                    #endif
                    for diseaseGroup in diseaseGroups {
                        await statistics.updateGroup(url: diseaseGroup, count: count)
                    }
                }

            }

            try await printStatistics(statistics: statistics)

        } catch {
            print("Failed to generate statistics")
            print("Error: \(error)")
        }
    }

}

