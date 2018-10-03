//
//  OLS.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

class OntologyLookupService {

    struct Page: Codable {
        var size: Int
        var totalElements: Int
        var totalPages: Int
        var number: Int
    }

    struct Link: Codable {
        var href: URL
    }

    struct Links: Codable {
//        var first: Link
        var next: Link?
//        var previous: Link?
//        var last: Link
//        var this: Link
//
//        enum CodingKeys: String, CodingKey {
//            case first, next, previous, last, this = "self"
//        }
    }

    struct Embedded: Codable {
        var terms: [Node]
    }

    struct Terms: Codable {
        var data: Embedded
        var links: Links
//        var page: Page

        enum CodingKeys: String, CodingKey {
            case data = "_embedded"
            case links = "_links"
//            case page
        }
    }

    struct Node: Codable, Hashable {
        var iri: URL
        var label: String

        var shortForm: String {
            return iri.lastPathComponent
        }
    }

    struct Edge: Codable, Hashable {
        var source: URL
        var target: URL
        var label: String
        var uri: URL
    }

    struct Graph: Codable {
        var nodes: [Node]
        var edges: [Edge]
    }

    let olsEndPoint: URL = "https://www.ebi.ac.uk/ols/api/ontologies/ORDO/terms"
    var vertices: Set<Node>
    var edges: Set<Edge>
    let decode = JSONDecoder()
    let ready: DispatchSemaphore
    let queue = DispatchQueue(label: "update")

    init() {
        ready = DispatchSemaphore(value: 0)
        vertices = Set<Node>()
        edges = Set<Edge>()
        var components = URLComponents(url: olsEndPoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [ URLQueryItem(name: "size", value: "1000")]
        get(url: components.url!, completion: initializeVertices)
    }

    private func get(url: URL, completion: @escaping (Data) -> ()) {
        print(url.absoluteString)
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) {data, request, errors in
            guard let data = data else { fatalError(errors?.localizedDescription ?? "Unexpected condition") }
            completion(data)
        }.resume()
    }

    private func initializeVertices(data: Data) {
        do {
            let result = try decode.decode(Terms.self, from: data)
            for term in result.data.terms {
                vertices.update(with: term)
            }
            if let next = result.links.next {
                get(url: next.href, completion: initializeVertices)
            } else {
                initializeEdges()
            }
        } catch let error {
            fatalError(error.localizedDescription)
        }
    }

    private func initializeEdges() {
        let group = DispatchGroup()
        vertices.forEach { (edge) in
            group.enter()
            var charset = CharacterSet.alphanumerics
            charset.formUnion(CharacterSet(charactersIn: "_"))
            let uri = edge.iri.absoluteString.addingPercentEncoding(withAllowedCharacters: charset)!
            let graphURL = olsEndPoint.appendingPathComponent(uri).appendingPathComponent("graph")
            var request = URLRequest(url: graphURL)
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            URLSession.shared.dataTask(with: request) {data, request, errors in
                guard let data = data else { fatalError(errors?.localizedDescription ?? "Unexpected condition") }
                do {
                    let result = try self.decode.decode(Graph.self, from: data)
                    self.queue.async {
                        self.edges.formUnion(result.edges)
                        print("Edges: \(self.edges.count)")
                        group.leave()
                    }
                } catch let error {
                    fatalError(error.localizedDescription)
                }
            }.resume()
        }
        DispatchQueue.global().async {
            defer {
                self.ready.signal()
            }
//            _ = group.wait(wallTimeout: .now() + .seconds(5))
            group.wait()
        }
    }
}
