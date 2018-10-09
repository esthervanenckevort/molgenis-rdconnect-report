//
//  OLS.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation
/// see: https://www.ebi.ac.uk/ols/docs/api
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

    func depthFirstSearch(starting iri: URL, direction: Direction = .outgoing, shouldTraverse: (Edge) -> Bool) throws {
        var seen = [URL]()
        try depthFirstSearch(starting: iri, direction: direction, seen: &seen, shouldTraverse: shouldTraverse)
    }

    func node(for iri: URL) throws -> Node? {
        if let node = nodeCache.object(forKey: iri as NSURL) {
            return node
        }
        let uri = iri.absoluteString.addingPercentEncoding(withAllowedCharacters: charset)!
        let graphURL = olsEndPoint.appendingPathComponent(uri)
        guard let node = download(Node.self, url: graphURL)  else { return nil }
        nodeCache.setObject(node, forKey: iri as NSURL)
        return node
    }

    private func graph(for iri: URL) throws -> Graph? {
        if let graph = graphCache.object(forKey: iri as NSURL) {
            return graph
        }
        let uri = iri.absoluteString.addingPercentEncoding(withAllowedCharacters: charset)!
        let graphURL = olsEndPoint.appendingPathComponent(uri).appendingPathComponent("graph")
        guard let graph = download(Graph.self, url: graphURL) else { return nil }
        graphCache.setObject(graph, forKey: iri as NSURL)
        return graph
    }

    private func download<T: Decodable>(_ type: T.Type, url: URL) -> T? {
        let task = DispatchGroup()
        var result: T?
        task.enter()
        session.dataTask(with: url) { (data, response, error) in
            defer {
                task.leave()
            }
            guard let data = data else { fatalError("Failed to retrieve \(url): \(error?.localizedDescription ?? "")") }
            do {
                result = try self.decoder.decode(type, from: data)
            } catch {
                fatalError("Failed to retrieve \(url): \(error.localizedDescription)")
            }
            }.resume()
        task.wait()

        return result

    }

    private func depthFirstSearch(starting iri: URL, direction: Direction, seen: inout [URL], shouldTraverse: (Edge) -> Bool) throws {
        seen.append(iri)
        for edge in try edges(for: iri, direction: direction) {
            guard !seen.contains(edge.target) else { continue }
            if shouldTraverse(edge) {
                try depthFirstSearch(starting: edge.target, direction: direction, seen: &seen, shouldTraverse: shouldTraverse)
            }
        }
    }

    private func edges(for iri: URL, direction: Direction) throws -> [Edge] {
        var edges = [Edge]()
        let graph = try self.graph(for: iri)
        switch direction {
        case .incoming:
            edges = graph?.edges.filter { return $0.target == iri } ?? []
        case .outgoing:
            edges = graph?.edges.filter { return $0.source == iri } ?? []
        case .both:
            edges = graph?.edges ?? []
        }
        return edges
    }

}
