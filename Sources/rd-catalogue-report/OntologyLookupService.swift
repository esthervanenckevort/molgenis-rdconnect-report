//
//  OLS.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by Esther van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation
/// see: https://www.ebi.ac.uk/ols/docs/api
@available(macOS 12.0.0, *)
class OntologyLookupService {

    class Node: Codable {
        var iri: URL
        var label: String
    }

    struct Edge: Codable, Hashable {
        var source: URL
        var target: URL
        var label: String
        var uri: URL
    }

    class Graph: Codable {
        var nodes: [Node]
        var edges: [Edge]
    }

    private let olsEndPoint: URL = "https://www.ebi.ac.uk/ols/api/ontologies/ORDO/terms"
    private let decoder = JSONDecoder()
    private let session: URLSession
    private let charset: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.formUnion(CharacterSet(charactersIn: "_"))
        return set
    }()
    private var graphCache = NSCache<NSURL, Graph>()
    private var nodeCache = NSCache<NSURL, Node>()

    init() {
        let config = URLSessionConfiguration.default
        config.httpAdditionalHeaders = ["Accept": "application/json"]
        session = URLSession(configuration: config)
    }

    enum Direction {
        case incoming, outgoing, both
    }

    func depthFirstSearch(starting iri: URL, direction: Direction = .outgoing, shouldTraverse: (Edge) -> Bool, isMatch: (Edge) -> Bool) async throws -> [URL] {
        var seen = [URL]()
        return try await depthFirstSearch(starting: iri, direction: direction, seen: &seen, shouldTraverse: shouldTraverse, isMatch: isMatch)
    }

    func node(for iri: URL) async throws -> Node {
        if let node = nodeCache.object(forKey: iri as NSURL) {
            return node
        }
        let uri = iri.absoluteString.addingPercentEncoding(withAllowedCharacters: charset)!
        let graphURL = olsEndPoint.appendingPathComponent(uri)
        let node = try await download(Node.self, url: graphURL)
        nodeCache.setObject(node, forKey: iri as NSURL)
        return node
    }

    private func graph(for iri: URL) async throws -> Graph {
        if let graph = graphCache.object(forKey: iri as NSURL) {
            return graph
        }
        let uri = iri.absoluteString.addingPercentEncoding(withAllowedCharacters: charset)!
        let graphURL = olsEndPoint.appendingPathComponent(uri).appendingPathComponent("graph")
        let graph = try await download(Graph.self, url: graphURL)
        graphCache.setObject(graph, forKey: iri as NSURL)
        return graph
    }

    private func download<T: Decodable>(_ type: T.Type, url: URL) async throws -> T {
        let (data, _) = try await session.data(from: url)
        return try self.decoder.decode(type, from: data)
    }

    private func depthFirstSearch(starting iri: URL, direction: Direction, seen: inout [URL], shouldTraverse: (Edge) async -> Bool, isMatch: (Edge) -> Bool) async throws -> [URL] {
        seen.append(iri)
        var results = [URL]()
        let edges = try await edges(for: iri, direction: direction)

        for edge in edges {
            guard !seen.contains(edge.target) else { continue }
            if isMatch(edge) {
                results.append(edge.source)
            }
            if await shouldTraverse(edge) {
                let matches = try await depthFirstSearch(starting: edge.target, direction: direction, seen: &seen, shouldTraverse: shouldTraverse, isMatch: isMatch)
                results.append(contentsOf: matches)
            }
        }
        return results
    }

    private func edges(for iri: URL, direction: Direction) async throws -> [Edge] {
        var edges = [Edge]()
        let graph = try await self.graph(for: iri)
        switch direction {
        case .incoming:
            edges = graph.edges.filter { return $0.target == iri }
        case .outgoing:
            edges = graph.edges.filter { return $0.source == iri }
        case .both:
            edges = graph.edges
        }
        return edges
    }

}
