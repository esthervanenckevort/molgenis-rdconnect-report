//
//  Result.swift
//  Rare Disease Sample Catalogue Reporting
//
//  Created by David van Enckevort on 08/10/2018.
//  Copyright © 2018 All Things Digital. All rights reserved.
//

import Foundation

enum Result<T> {
    case success(result: T)
    case error(error: Error)
}
