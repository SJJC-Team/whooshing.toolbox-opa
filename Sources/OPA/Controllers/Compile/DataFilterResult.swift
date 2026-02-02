import Foundation
@preconcurrency import AnyCodable

public extension OPA.CompileController {
    /// SQL 目标过滤结果
    struct SQLTargetResult: Codable, Sendable {
        /// 生成的 SQL 查询字符串
        let query: String
    }
    
    /// UCAST 目标过滤结果
    struct UCASTTargetResult: Codable, Sendable {
        /// 生成的 UCAST 查询对象 (JSON)
        let query: [String: AnyCodable]
    }
    
    /// 多目标过滤结果
    struct MultiTargetResult: Codable, Sendable {
        /// UCAST 结果
        let ucast: Value<[String: AnyCodable]>?
        /// PostgreSQL 结果
        let postgresql: Value<String>?
        /// MySQL 结果
        let mysql: Value<String>?
        /// SQL Server 结果
        let sqlserver: Value<String>?
        /// SQLite 结果
        let sqlite: Value<String>?
        
        /// 多目标结果值包装器
        struct Value<T: Codable & Sendable>: Codable, Sendable {
            /// 具体查询内容
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
