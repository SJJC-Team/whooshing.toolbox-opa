import Foundation
@preconcurrency import AnyCodable

public extension OPA.CompileController {
    struct SQLTargetResult: Codable, Sendable {
        let query: String
    }
    
    struct UCASTTargetResult: Codable, Sendable {
        let query: [String: AnyCodable]
    }
    
    struct MultiTargetResult: Codable, Sendable {
        let ucast: Value<[String: AnyCodable]>?
        let postgresql: Value<String>?
        let mysql: Value<String>?
        let sqlserver: Value<String>?
        let sqlite: Value<String>?
        
        struct Value<T: Codable & Sendable>: Codable, Sendable {
            let query: T
        }
    }
}

extension OPA.CompileController.SQLTargetResult: CustomStringConvertible {
    public var description: String {
        return "SQLTarget(\(query))"
    }
}

extension OPA.CompileController.UCASTTargetResult: CustomStringConvertible {
    public var description: String {
        return "UCASTTarget(\(query))"
    }
}

extension OPA.CompileController.MultiTargetResult: CustomStringConvertible {
    public var description: String {
        var outputs: [String] = []
        
        if let mysql = mysql { outputs.append("MySQL: \(mysql)") }
        if let pg = postgresql { outputs.append("PostgreSQL: \(pg)") }
        if let ss = sqlserver { outputs.append("SQLServer: \(ss)") }
        if let lite = sqlite { outputs.append("SQLite: \(lite)") }
        
        if let ucast = ucast, !ucast.query.isEmpty {
            outputs.append("uCAST: \(ucast.query.count) nodes")
        }
        
        if outputs.isEmpty {
            return "MultiTarget(empty)"
        }
        
        return "MultiTarget(\n" + outputs.joined(separator: "\t\n") + "\n)"
    }
}
