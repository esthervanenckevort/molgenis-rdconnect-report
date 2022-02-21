//
//  Resources.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by Esther van Enckevort on 03/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

extension URL: ExpressibleByStringLiteral {
    public typealias StringLiteralType = StaticString

    public init(stringLiteral string: StaticString) {
        self.init(string: string.description)!
    }
}
