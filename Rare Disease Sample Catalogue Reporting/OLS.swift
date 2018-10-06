//
//  OLS.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

class OntologyLookupService {

    struct Link: Codable {
        var href: URL
    }

    struct Links: Codable {
        var next: Link?
    }

    struct Embedded: Codable {
        var terms: [Node]
    }

    struct Terms: Codable {
        var data: Embedded
        var links: Links

        enum CodingKeys: String, CodingKey {
            case data = "_embedded"
            case links = "_links"
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
    let session: URLSession
    var graph: (nodes: [URL:[Node]], edges: [URL:[Edge]])?

    init() {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 5
        config.urlCache = URLCache(memoryCapacity: 100_000_000, diskCapacity: 1_000_000_000, diskPath: "/tmp/orphanet.cache")
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        session = URLSession(configuration: config)
        ready = DispatchSemaphore(value: 0)
        vertices = Set<Node>()
        edges = Set<Edge>()
        var components = URLComponents(url: olsEndPoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [ URLQueryItem(name: "size", value: "1000")]
        get(url: components.url!, completion: initializeVertices)
    }

    func findVertex(with iri: URL) -> Node? {
        return graph?.nodes[iri]?.first
    }

    func depthFirstSearch(starting iri: URL, shouldTraverse: (Edge) -> Bool) {
        var seen = [URL]()
        depthFirstSearch(starting: iri, seen: &seen, shouldTraverse: shouldTraverse)
    }
    private func depthFirstSearch(starting iri: URL, seen: inout [URL], shouldTraverse: (Edge) -> Bool) {
        seen.append(iri)
        for edge in graph?.edges[iri] ?? [] {
            guard !seen.contains(edge.target) else { continue }
            if shouldTraverse(edge) {
                depthFirstSearch(starting: edge.target, seen: &seen, shouldTraverse: shouldTraverse)
            }
        }
    }

    private func get(url: URL, completion: @escaping (Data) -> ()) {
        session.dataTask(with: url) {data, request, errors in
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
            session.dataTask(with: graphURL) {data, request, error in
                guard let data = data else {
                    print("Failed to load edges for \(graphURL) \(error?.localizedDescription ?? "Unexpected condition")")
                    group.leave()
                    return
                }
                do {
                    let result = try self.decode.decode(Graph.self, from: data)
                    self.queue.async {
                        self.edges.formUnion(result.edges)
                        print("Edges: \(self.edges.count)")
                        group.leave()
                    }
                } catch let error {
                    print("Failed to load edges for \(graphURL) \(error.localizedDescription)")
                    group.leave()
                }
            }.resume()
        }
        DispatchQueue.global().async {
            defer {
                self.ready.signal()
            }
            group.wait()
            let nodes = Dictionary<URL, [Node]>(grouping: self.vertices) { return $0.iri }
            let edges = Dictionary<URL, [Edge]>(grouping: self.edges) { return $0.source }
            self.graph = (nodes, edges)
        }
    }
}
