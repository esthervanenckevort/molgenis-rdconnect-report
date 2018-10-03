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
let group = ols.vertices.filter { (vertex) -> Bool in
    return vertex.iri == "http://www.orpha.net/ORDO/Orphanet_377794"
}
let groups = ols.edges.filter { (vertex) -> Bool in
    return vertex.target == "http://www.orpha.net/ORDO/Orphanet_377794"
}
print(groups.map { (edge) -> String in
    let vertex = ols.findVertex(with: edge.source)
    return vertex?.label ?? "\(edge.source) does not exist"
})

