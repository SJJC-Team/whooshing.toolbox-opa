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
        -------------------------------------------
        SQL Target Query Result:
        
        \(query)
        -------------------------------------------
        """
    }
}

// MARK: - UCASTTargetResult Description
extension OPA.CompileController.UCASTTargetResult: Loggerable, CustomStringConvertible {
    public var description: String {
        var output = """
        -------------------------------------------
        UCAST Target Query Result:
        
        """
        
        let formattedQuery = formatQuery(query)
        
        let indentedQuery = formattedQuery.components(separatedBy: .newlines)
                                          .joined(separator: "\n")
        
        output += "\n\(indentedQuery)"
        output += "\n-------------------------------------------"

        return output
    }
}

// MARK: - MultiTargetResult Description

extension OPA.CompileController.MultiTargetResult: Loggerable, CustomStringConvertible {
    public var description: String {
        var sections: [String] = []
        
        // 1. 处理 UCAST (JSON 结构)
        if let ucastResult = ucast {
            let formattedJSON = formatQuery(ucastResult.query)
            let indentedJSON = formattedJSON.components(separatedBy: .newlines)
                                            .joined(separator: "\n")
            sections.append("UCAST: \(indentedJSON)")
        }
        
        // 2. 处理 SQL 目标 (String 结构)
        // 我们可以定义一个统一的闭包来处理 SQL 类型的打印
        let addSQLSection = { (name: String, query: String?) in
            if let q = query {
                sections.append("\(name):\n\(q)")
            }
        }
        
        addSQLSection("PostgreSQL", postgresql?.query)
        addSQLSection("MySQL", mysql?.query)
        addSQLSection("SQL Server", sqlserver?.query)
        addSQLSection("SQLite", sqlite?.query)
        
        // 3. 组装最终输出
        guard !sections.isEmpty else {
            return "-------------------------------------------\nMultiTargetResult: [EMPTY]\n-------------------------------------------"
        }
        
        let body = sections.joined(separator: "\n\n")
        return """
        -------------------------------------------
        Multi-Target Compile Results:
        
        \(body)
        -------------------------------------------
        """
    }
}

func formatQuery(_ query: [String: AnyCodable]) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    
    do {
        let data = try encoder.encode(query)
        return String(data: data, encoding: .utf8) ?? "\(query)"
    } catch {
        return "\(query)"
    }
}
