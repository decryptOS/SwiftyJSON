//
//  Dictionary+MapValues.swift
//  SwiftyJSON
//
//  Created by Johannes Roth on 11.07.17.
//
//

#if swift(>=4.0)
#else
    internal extension Dictionary {
        internal func mapValues<T>(_ transform: (Value) throws -> T) rethrows -> [Key : T] {
            var result = [Key : T]()
            
            for (key, value) in self {
                result[key] = try transform(value)
            }
            
            return result
        }
    }
#endif
