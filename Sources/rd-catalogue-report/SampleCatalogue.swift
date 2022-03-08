//
//  Samples.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by Esther van Enckevort on 06/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation



class SampleCatalogue {
    private let sampleCatalogueEndpoint: URL = URL(string: "https://samples.rd-connect.eu/api/v2/rd_connect_Sample?aggs=x==Disease")!

    struct Aggregates<X>: Decodable where X: Decodable {
        var matrix: [[Int]]
        var xLabels: [X]
    }

    private struct Response<T>: Decodable where T: Decodable {
        var aggs: T
    }

    private var decoder = JSONDecoder()

    func aggregatePerDisease() async throws -> Aggregates<Disease> {
        let (data, _) = try await URLSession.shared.data(from: sampleCatalogueEndpoint)
        let result = try decoder.decode(Response<Aggregates<Disease>>.self, from: data)
        return result.aggs
    }
}
