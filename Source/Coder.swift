//
//  Coder.swift
//  SwiftyJSON
//
//  Created by Johannes Roth on 11.07.17.
//
//

import Foundation

#if swift(>=3.1)
    public typealias RegularExpression = NSRegularExpression
#endif

public typealias JSONCodable = JSONEncodable & JSONDecodable

extension JSON {
    init(safeFrom data: Data, options: JSONSerialization.ReadingOptions = .allowFragments) throws {
        let object: Any = try JSONSerialization.jsonObject(with: data, options: options)
        self.init(object)
    }
}

public enum JSONEncodingError: Error {
    case unencodableType(Any.Type)
    case failedToCreateFile
}

public protocol JSONEncodable {
    func encode(to json: inout JSON) throws
}

extension JSONEncodable {
    public func encode(to data: inout Data) throws {
        var json: JSON = [:]
        try encode(to: &json)
        data = try json.rawData()
    }
}

extension JSONEncodable {
    public func encodeAsFile(atPath path: String) throws {
        var data = Data()
        try encode(to: &data)
        
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        if !FileManager.default.createFile(atPath: expandedPath, contents: data) {
            throw JSONEncodingError.failedToCreateFile
        }
    }
}

extension JSONEncodable {
    public func encode(to json: inout JSON) throws {
        let mirror = Mirror(reflecting: self)
        
        for (name, value) in mirror.children {
            guard let key = name else {
                continue
            }
            
            switch value {
            case let bool as Bool:
                json.encode(bool, forKey: key)
                
            case let int as Int:
                json.encode(int, forKey: key)
                
            case let double as Double:
                json.encode(double, forKey: key)
                
            case let string as String:
                json.encode(string, forKey: key)
                
            case let encodable as JSONEncodable:
                try json.encode(encodable, forKey: key)
                
            case let array as [JSONEncodable]:
                try json.encode(array, forKey: key)
                
            case let dictionary as [String : JSONEncodable]:
                try json.encode(dictionary, forKey: key)
                
            default:
                throw JSONEncodingError.unencodableType(type(of: value))
            }
        }
    }
}

extension JSON {
    public mutating func encode(_ value: NSNull, forKey key: String) {
        self[key] = .null
    }
    
    public mutating func encode(_ value: JSON, forKey key: String) {
        self[key] = value
    }
    
    public mutating func encode(_ value: Bool, forKey key: String) {
        self[key] = JSON(booleanLiteral: value)
    }
    
    public mutating func encode(_ value: Int, forKey key: String) {
        self[key] = JSON(integerLiteral: value)
    }
    
    public mutating func encode(_ value: Double, forKey key: String) {
        self[key] = JSON(floatLiteral: value)
    }
    
    public mutating func encode(_ value: String, forKey key: String) {
        self[key] = JSON(stringLiteral: value)
    }
    
    public mutating func encode(_ url: URL, forKey key: String) {
        self[key] = JSON(stringLiteral: url.absoluteString)
    }
    
    public mutating func encode(_ value: JSONEncodable, forKey key: String) throws {
        var json: JSON = [:]
        try value.encode(to: &json)
        self[key] = json
    }
    
    public mutating func encode(_ value: [String], forKey key: String) {
        self[key] = JSON(value)
    }
    
    public mutating func encode(_ array: [JSONEncodable], forKey key: String) throws {
        let jsonArray: [JSON] = try array.map { (value) -> JSON in
            var json: JSON = [:]
            try value.encode(to: &json)
            
            return json
        }
        
        self[key] = JSON(jsonArray)
    }
    
    public mutating func encode(_ dictionary: [String : JSONEncodable], forKey key: String) throws {
        var json: JSON = [:]
        
        for (key, value) in dictionary {
            var encodedValue: JSON = [:]
            try value.encode(to: &encodedValue)
            
            json[key] = encodedValue
        }
        
        self[key] = json
    }
}

public enum JSONDecodingError: Error {
    case missingKey(String)
    case invalidURL(String)
    case unexpectedArrayElement(Any)
    case fileNotFound
    case badDictionary
}

public protocol JSONDecodable {
    init(decoding json: JSON) throws
}

extension JSONDecodable {
    public init(decoding data: Data) throws {
        let json = try JSON(safeFrom: data)
        
        try self.init(decoding: json)
    }
}

extension JSONDecodable {
    public init(decodingFileAtPath path: String) throws {
        let expandedPath = NSString(string: path).expandingTildeInPath
        
        guard let data = FileManager.default.contents(atPath: expandedPath) else {
            throw JSONDecodingError.fileNotFound
        }
        
        try self.init(decoding: data)
    }
}

extension JSON {
    public func decode(forKey key: String) throws -> JSON {
        return self[key]
    }
    
    public func decode(forKey key: String) throws -> String {
        if let value = self[key].string {
            return value
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> Int {
        if let value = self[key].int {
            return value
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> Bool {
        if let value = self[key].bool {
            return value
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> URL {
        if let value = self[key].string {
            if let url = Foundation.URL(string: value) {
                return url
            } else {
                throw JSONDecodingError.invalidURL(value)
            }
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> RegularExpression {
        if let pattern = self[key].string {
            return try RegularExpression(pattern: pattern, options: [])
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode<T : JSONDecodable>(forKey key: String) throws -> T {
        return try T(decoding: self[key])
    }
    
    public func decode<T : JSONDecodable>(forKey key: String) throws -> [T] {
        if let array = self[key].array {
            var typeArray = [T]()
            typeArray.reserveCapacity(array.count)
            
            for element in array {
                typeArray.append(try T(decoding: element))
            }
            
            return typeArray
            
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> [String] {
        if let array = self[key].arrayObject as? [String] {
            return array
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> [RegularExpression] {
        if let array = self[key].array {
            var regexArray = [RegularExpression]()
            regexArray.reserveCapacity(array.count)
            
            for element in array {
                if let string = element.string {
                    regexArray.append(try RegularExpression(pattern: string, options: []))
                } else {
                    throw JSONDecodingError.unexpectedArrayElement(element)
                }
            }
            
            return regexArray
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode(forKey key: String) throws -> [String : String] {
        if let dictionary = self[key].dictionaryObject {
            if let result = dictionary as? [String : String] {
                return result
            } else {
                throw JSONDecodingError.badDictionary
            }
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
    
    public func decode<T : JSONDecodable>(forKey key: String) throws -> [String : T] {
        if let dictionary = self[key].dictionary {
            return try dictionary.mapValues { (json) throws -> T in
                return try T(decoding: json)
            }
        } else {
            throw JSONDecodingError.missingKey(key)
        }
    }
}
