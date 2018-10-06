//
//  Samples.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 06/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

class Samples {
    private let sampleCatalogueEndpoint: URL = "https://samples.rd-connect.eu/api/v2/RD_connect_Sample?aggs=x==Disease"

    struct Disease: Codable {
        var IRI: String
        var preferredTerm: String
        var id: String
        var code: String
        enum CodingKeys: String, CodingKey {
            case IRI, preferredTerm = "PreferredTerm", id = "ID", code = "Code"
        }
    }
    struct Aggregates: Codable {
        var matrix: [[Int]]
        var xLabels: [Disease]
    }

    struct Result: Codable {
        var aggs: Aggregates
    }

    private var decode = JSONDecoder()
    var aggregates = [URL: Int]()

    init(_ group: DispatchGroup) {
        group.enter()
        URLSession.shared.dataTask(with: sampleCatalogueEndpoint) { (data, response, error) in
            defer {
                group.leave()
            }
            guard let data = data else { fatalError("Failed to load aggregates")}
            do {
                let result = try self.decode.decode(Result.self, from: data)

                for (disease, count) in zip(result.aggs.xLabels, result.aggs.matrix) {
                    guard disease.IRI.hasPrefix("urn:miriam:orphanet") else { continue }
                    guard let diseaseURL = URL(string: "http://www.orpha.net/ORDO/Orphanet_\(disease.code)") else { continue }
                    self.aggregates[diseaseURL] = count.first ?? 0
                }
            } catch let exception {
                fatalError(exception.localizedDescription)
            }

        }.resume()
    }
}
