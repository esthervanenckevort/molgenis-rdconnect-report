//
//  Disease.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 08/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

struct Disease: Decodable {
    static var name = "Disease"

    var IRI: String
    var preferredTerm: String
    var id: String
    var code: String
    enum CodingKeys: String, CodingKey {
        case IRI, preferredTerm = "PreferredTerm", id = "ID", code = "Code"
    }
}
