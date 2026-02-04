import Foundation
import LoggingAdvanced
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

// MARK: - SQLTargetResult Description
extension OPA.CompileController.SQLTargetResult: Loggerable, CustomStringConvertible {
    public var description: String {
        """
        sql_target:
          query: \(query)
        """
    }
}

// MARK: - UCASTTargetResult Description
extension OPA.CompileController.UCASTTargetResult: Loggerable, CustomStringConvertible {
    public var description: String {
        """
        ucast_target:
          query: \(query)
        """
    }
}

// MARK: - MultiTargetResult Description
extension OPA.CompileController.MultiTargetResult: Loggerable, CustomStringConvertible {
    public var description: String {
        var lines: [String] = ["multi_target:"]
        
        // 内部辅助函数：处理包装后的 Value
        func add<T>(_ label: String, _ value: Value<T>?) {
            guard let value = value else { return }
            lines.append("  \(label): \(value.query)")
        }

        // 逐一检查并添加非空目标
        add("ucast", ucast)
        add("postgresql", postgresql)
        add("mysql", mysql)
        add("sqlserver", sqlserver)
        add("sqlite", sqlite)
        
        return lines.joined(separator: "\n")
    }
}
