// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


import Foundation

public class Repository {
    private let repository: String
    private let url: URL
    private let session: URLSession
    private let labelPredicate = "http://www.w3.org/2000/01/rdf-schema#label"
    private let value = "value"
    private let charset: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.formUnion(CharacterSet(charactersIn: "_"))
        return set
    }()

    let cache = Cache()
    actor Cache {
        init() {
            cache = [URL:RDF_JSON]()
        }
        private var cache: [URL:RDF_JSON]

        func read(_ url: URL) -> RDF_JSON? {
            if let result = cache[url] {
                return result
            }
            return nil
        }
        
        func update(_ url: URL, with newValue: RDF_JSON) {
            cache[url] = newValue
        }
    }


    enum GraphDBError: Error {
        case decoding, httpError
    }

    init(url: URL, repository: String, session: URLSession = .shared) {
        self.url = url
        self.repository = repository
        self.session = session
    }

    public func depthFirstSearch(starting iri: String, direction: Direction, shouldTraverse: (Edge) -> Bool, isMatch: ([Edge]) -> Bool) async throws -> Set<String> {
        var data: RDF_JSON
        switch direction {
        case .incoming:
            data = try await statements(object: iri)
        case .outgoing:
            data = try await statements(subject: iri)
        case .both:
            let outgoing = try await depthFirstSearch(starting: iri, direction: .outgoing, shouldTraverse: shouldTraverse, isMatch: isMatch)
            let incoming = try await depthFirstSearch(starting: iri, direction: .incoming, shouldTraverse: shouldTraverse, isMatch: isMatch)
            return incoming.union(outgoing)
        }

        var result = Set<String>()

        // For each of the subjects create the set of triples
        for subject in data.keys {
            var edges = [Edge]()
            guard let predicateObjectsPair = data[subject] else { throw GraphDBError.decoding }

            for predicate in predicateObjectsPair.keys {
                guard let objects = predicateObjectsPair[predicate] else { throw GraphDBError.decoding }
                for object in objects {
                    let edge = (subject: subject, predicate: predicate, object: object)
                    edges.append(edge)
                }
            }

            if isMatch(edges) {
                result.insert(subject)
            }

            for edge in edges {
                if shouldTraverse(edge) {
                    result = result.union(try await depthFirstSearch(starting: edge.object.value, direction: direction, shouldTraverse: shouldTraverse, isMatch: isMatch))
                }
            }
        }
        return result
    }

    public func node(for iri: String) async throws -> Node {
        let subjects = try await statements(subject: iri, predicate: labelPredicate)
        guard let edges = subjects[iri] else { throw GraphDBError.decoding }
        guard let labels = edges[labelPredicate] else { throw GraphDBError.decoding }
        let label = labels.first(where: { $0.lang == "en" })
        return (iri, label?.value ?? labels.first?.value ?? "N/A")
    }

    private func statements(subject: String? = nil, predicate: String? = nil, object: String? = nil) async throws -> RDF_JSON {
        let statementsURL = url.appendingPathComponent("repositories").appendingPathComponent(repository).appendingPathComponent("statements")
        var statement = URLComponents(url: statementsURL, resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem]()

        if let subject = subject {
            let item = URLQueryItem(name: "subj", value: "<\(subject)>")
            queryItems.append(item)
        }
        if let predicate = predicate {
            let item = URLQueryItem(name: "pred", value: "<\(predicate)>")
            queryItems.append(item)
        }
        if let object = object {
            let item = URLQueryItem(name: "obj", value: "<\(object)>")
            queryItems.append(item)
        }
        guard queryItems.count > 0 else { fatalError("Query must have at least one constraint") }
        statement.queryItems = queryItems

        let url = statement.url!
        var request = URLRequest(url: url)
        request.setValue("application/rdf+json", forHTTPHeaderField: "Accept")
        if let json = await cache.read(url) {
            return json
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw GraphDBError.httpError
        }

        do {
            let json = try JSONDecoder().decode(RDF_JSON.self, from: data)
            await cache.update(url, with: json)
            return json
        } catch {
            print("Failed to decode response from: \(statementsURL)")
            print(String(data: data, encoding: .utf8) ?? data)
            print(error)
            throw GraphDBError.decoding
        }
    }
}

typealias RDF_JSON = [String:[String:[Object]]]
public typealias Edge = (subject: String, predicate: String, object: Object)
public typealias Node = (iri: String, label: String)

public struct Object: Codable {
    let value: String
    let type: ObjectType
    let lang: String?
    let dataType: String?
}

public enum ObjectType: String, Codable {
    case literal, uri, bnode
}
