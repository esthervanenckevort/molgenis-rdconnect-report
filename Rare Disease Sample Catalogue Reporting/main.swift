//
//  main.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

struct Resources {
    let sampleCatalogueEndpoint: URL = "https://samples.rd-connect.eu/api/v2/RD_connect_Sample?aggs=x==Disease"

}


let ols = OntologyLookupService()
ols.ready.wait()
print("Vertices: \(ols.vertices.count) Edges: \(ols.edges.count)")
//ols.edges.forEach { (edge) in
//    print("\(edge.source) \(edge.label) \(edge.target)")
//}
