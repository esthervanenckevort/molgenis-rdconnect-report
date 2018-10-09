//
//  Samples.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 06/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation



class SampleCatalogue {
    private let sampleCatalogueEndpoint: URL = "https://samples.rd-connect.eu/api/v2/RD_connect_Sample?aggs=x==Disease"

    struct Aggregates<X>: Decodable where X: Decodable {
        var matrix: [[Int]]
        var xLabels: [X]
    }

    private struct Response<T>: Decodable where T: Decodable {
        var aggs: T
    }

    private var decoder = JSONDecoder()

    func aggregatePerDisease(completion: @escaping (Result<Aggregates<Disease>>) -> ()) {
        URLSession.shared.dataTask(with: sampleCatalogueEndpoint) { (data, response, error) in
            guard let data = data else { fatalError("Failed to load aggregates")}
            do {
                let result = try self.decoder.decode(Response<Aggregates<Disease>>.self, from: data)
                completion(Result.success(result: result.aggs))
            } catch let exception {
                completion(Result.error(error: exception))
            }

        }.resume()
    }
}
