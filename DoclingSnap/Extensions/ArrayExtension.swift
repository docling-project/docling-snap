//
//  ArrayExtension.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/17/25.
//

import Foundation

extension Array where Element == UInt8 {
    var deobfuscated: [UInt8] {
        let a = prefix(count / 2)
        let b = suffix(count / 2)
        return zip(a, b).map(^)
    }
}
