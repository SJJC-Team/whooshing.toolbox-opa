import Foundation
import LoggingAdvanced
@preconcurrency import AnyCodable

public extension OPA.CompileController {
    /// SQL 目标过滤结果
    ///
    /// 表示 Compile API 针对 SQL 目标生成的编译结果。
    /// 可以直接用于数据库查询。
    struct SQLTargetResult: Codable, Sendable {
        /// 生成的 SQL 查询字符串 (例如: `t1.x = 'a' AND t1.y = 'b'`)
        let query: String
    }
    
    /// UCAST 目标过滤结果
    ///
    /// 表示 Compile API 针对 UCAST (Universal Abstract Syntax Tree) 目标生成的编译结果。
    /// 可以用于转换为其他数据库查询语言，如 MongoDB, ElasticSearch 等。
    struct UCASTTargetResult: Codable, Sendable {
        /// 生成的 UCAST 查询对象 (JSON 格式)
        let query: [String: AnyCodable]
    }
    
    /// 多目标过滤结果
    ///
    /// 当请求中指定多个 Compile 目标时返回的结果容器。
    /// 包含了各个目标的编译结果。
    struct MultiTargetResult: Codable, Sendable {
        /// UCAST 结果，如果请求包含 ucast 目标
        let ucast: Value<[String: AnyCodable]>?
        /// PostgreSQL 结果，如果请求包含 sql+postgresql 目标
        let postgresql: Value<String>?
        /// MySQL 结果，如果请求包含 sql+mysql 目标
        let mysql: Value<String>?
        /// SQL Server 结果，如果请求包含 sql+sqlserver 目标
        let sqlserver: Value<String>?
        /// SQLite 结果，如果请求包含 sql+sqlite 目标
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
