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
        print("Diseases: \(await statistics.countsPerDisease.count)")
        #if DEBUG
        print("=============================================\nUnclassified: \(await statistics.countsUnclassified.values.reduce(0, +))")
        for (iri, count) in await statistics.countsUnclassified {
            let node = try await ols.node(for: iri)
            print("\(node.label) (\(iri)): \(count)")
        }
        #endif
    }


    static func main() async throws {
        do {
            let statistics = Statistics()

            let aggregates = try await sampleCatalogue.aggregatePerDisease()

            for (counts, disease) in zip(aggregates.matrix, aggregates.xLabels) {

                // We only process those disease codes that are from Orphanet
                guard disease.IRI.starts(with: "urn:miriam:orphanet") else {
                    continue
                }

                // Only if there are counts for the disease
                guard let count = counts.first else {
                    continue
                }

                let diseaseURL = "http://www.orpha.net/ORDO/Orphanet_\(disease.code)"
                await statistics.updateDisease(url: diseaseURL, count: count)

                let diseaseGroups = try await ols.depthFirstSearch(starting: diseaseURL, direction: .outgoing, shouldTraverse: ORDO.isSubClassOrPartOfRelationship, isMatch: ORDO.isMainCategory)

                if diseaseGroups.count == 0 {
                    let types = try await ols.object(subject: diseaseURL, predicate: ORDO.subClassOf.rawValue)
                    if types.contains(where: { $0 == ORDO.inActiveClinicalEntity.rawValue || $0 == ORDO.clinicalEntity.rawValue }) {
                        await statistics.updateUnclassified(url: diseaseURL, count: count)
                    } else {
                        print("\(disease.preferredTerm) (ORPHA:\(disease.code)) is not a clinical entity")
                    }

                } else {
                    for diseaseGroup in diseaseGroups {
                        await statistics.updateGroup(url: diseaseGroup, count: count)
                        if ORDO.inactive.contains(diseaseGroup) {
                            printMessage(disease: disease, group: diseaseGroup)
                        }
                    }
                }

            }

            try await printStatistics(statistics: statistics)

        } catch {
            print("Failed to generate statistics")
            print("Error: \(error)")
        }
    }

    static func printMessage(disease: Disease, group: String) {
        switch group {
        case ORDO.obsoleteClinicalEntity.rawValue:
            print("\(disease.preferredTerm) (ORPHA:\(disease.code)) is obsolete.")
        case ORDO.nonRareClinicalEntity.rawValue:
            print("\(disease.preferredTerm) (ORPHA:\(disease.code)) is not rare in Europe.")
        case ORDO.deprecatedClinicalEntity.rawValue:
            print("\(disease.preferredTerm) (ORPHA:\(disease.code)) is deprecated.")
        default:
            return
        }
    }

}

