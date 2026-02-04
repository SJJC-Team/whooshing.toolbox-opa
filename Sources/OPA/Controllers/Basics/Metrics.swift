import Foundation
import ErrorHandle
import LoggingAdvanced
@preconcurrency import AnyCodable

public extension OPA {
    /// OPA 性能度量指标
    struct Metrics: Decodable, Sendable {
        // --- 核心流程计时器 (Core Timers) ---
        // --- 核心流程计时器 (Core Timers) ---
        /// 输入数据解析耗时 (ns)
        ///
        /// 解析 HTTP 请求 Body 中的 Input JSON 的时间。
        public let timerRegoInputParse: Int64?
        /// 查询语句解析耗时 (ns)
        ///
        /// 解析 URL 参数或 Body 中的 Rego 查询语句的时间。
        public let timerRegoQueryParse: Int64?
        /// 查询编译耗时 (ns)
        ///
        /// 将解析后的 AST 编译为可执行规则的时间。
        public let timerRegoQueryCompile: Int64?
        /// 查询评估/执行耗时 (ns)
        ///
        /// *这是最重要的性能指标之一*，表示实际执行策略评估的时间。
        public let timerRegoQueryEval: Int64?
        /// 模块解析耗时 (ns)
        ///
        /// 解析 Policy Module (.rego 文件) 的时间。
        public let timerRegoModuleParse: Int64?
        /// 模块编译耗时 (ns)
        ///
        /// 编译 Policy Module 的时间。
        public let timerRegoModuleCompile: Int64?
        /// 服务器处理总耗时 (ns)
        ///
        /// 从收到请求到发送响应的总时间 (包括网络 IO 等)。
        public let timerServerHandler: Int64?
        /// 外部引用解析耗时 (ns)
        ///
        /// 解析 Data 数据引用的时间。
        public let timerRegoExternalResolve: Int64?
        /// 部分求值 (Partial Evaluation) 耗时 (ns)
        ///
        /// 执行 Partial Query 的时间。
        public let timerRegoPartialEval: Int64?

        // --- 编译转换计时器 (Compile/Translate Timers) - 新增遗漏项 ---
        /// 评估约束条件耗时 (ns)。
        /// 在 Compile API 中，处理下推到数据库的约束逻辑时触发。
        let timerCompileEvalConstraints: Int64?
        /// 准备部分求值阶段耗时 (ns)。
        let timerCompilePrepPartial: Int64?
        /// 翻译查询耗时 (ns)。
        /// 例如将 Rego 查询翻译为 SQL 语句的耗时。
        let timerCompileTranslateQueries: Int64?

        // --- 编译阶段细节计时器 (Compile Stage Timers) ---
        /// 重写模板字符串阶段耗时 (ns)
        let timerCompileRewriteTemplate: Int64?
        /// 构建推导式索引阶段耗时 (ns)
        let timerQueryCompileBuildComprehensionIndex: Int64?
        /// 检查已弃用的内置函数阶段耗时 (ns)
        let timerQueryCompileCheckDeprecated: Int64?
        /// 检查关键字覆盖阶段耗时 (ns)
        let timerQueryCompileCheckKeywords: Int64?
        /// 安全检查阶段耗时 (ns)
        let timerQueryCompileCheckSafety: Int64?
        /// 类型检查阶段耗时 (ns)
        let timerQueryCompileCheckTypes: Int64?
        /// 检查未定义函数阶段耗时 (ns)
        let timerQueryCompileCheckUndefinedFuncs: Int64?
        /// 检查不安全内置函数阶段耗时 (ns)
        let timerQueryCompileCheckUnsafeBuiltins: Int64?
        /// 检查空调用/无效调用阶段耗时 (ns)
        let timerQueryCompileCheckVoidCalls: Int64?
        /// 解析引用阶段耗时 (ns)
        let timerQueryCompileResolveRefs: Int64?
        /// 重写推导式项阶段耗时 (ns)
        let timerQueryCompileRewriteComprehensionTerms: Int64?
        /// 重写动态项阶段耗时 (ns)
        let timerQueryCompileRewriteDynamicTerms: Int64?
        /// 重写等式/赋值项阶段耗时 (ns)
        let timerQueryCompileRewriteEquals: Int64?
        /// 重写表达式项阶段耗时 (ns)
        let timerQueryCompileRewriteExprTerms: Int64?
        /// 重写局部变量阶段耗时 (ns)
        let timerQueryCompileRewriteLocalVars: Int64?
        /// 重写 Print 调用阶段耗时 (ns)
        let timerQueryCompileRewritePrintCalls: Int64?
        /// 重写 With 语句值阶段耗时 (ns)
        let timerQueryCompileRewriteWithValues: Int64?

        // --- 操作级计时器 (Op Timers) ---
        let timerEvalOpPlug: Int64?
        let timerEvalOpResolve: Int64?
        let timerEvalOpRuleIndex: Int64?
        let timerPartialOpCopyPropagation: Int64?
        let timerPartialOpSaveSetContains: Int64?
        let timerPartialOpSaveUnify: Int64?

        // --- 计数器 (Counters) ---
        // --- 计数器 (Counters) ---
        /// 服务器查询缓存命中次数
        public let counterServerQueryCacheHit: Int64?
        /// 基础缓存未命中次数 (Eval Op)
        public let counterEvalOpBaseCacheMiss: Int64?

        // --- 直方图 (Instrument) ---
        /// Eval Plug 操作耗时分布
        public let histogramEvalOpPlug: Instrument?
        /// Eval Resolve 操作耗时分布
        public let histogramEvalOpResolve: Instrument?
        /// Eval Rule Index 操作耗时分布
        public let histogramEvalOpRuleIndex: Instrument?
        /// Partial Copy Propagation 操作耗时分布
        public let histogramPartialOpCopyPropagation: Instrument?
        /// Partial Save Set Contains 操作耗时分布
        public let histogramPartialOpSaveSetContains: Instrument?
        /// Partial Save Unify 操作耗时分布
        public let histogramPartialOpSaveUnify: Instrument?

        enum CodingKeys: String, CodingKey {
            case timerRegoInputParse = "timer_rego_input_parse_ns"
            case timerRegoQueryParse = "timer_rego_query_parse_ns"
            case timerRegoQueryCompile = "timer_rego_query_compile_ns"
            case timerRegoQueryEval = "timer_rego_query_eval_ns"
            case timerRegoModuleParse = "timer_rego_module_parse_ns"
            case timerRegoModuleCompile = "timer_rego_module_compile_ns"
            case timerServerHandler = "timer_server_handler_ns"
            case timerRegoExternalResolve = "timer_rego_external_resolve_ns"
            case timerRegoPartialEval = "timer_rego_partial_eval_ns"

            case timerCompileEvalConstraints = "timer_compile_eval_constraints_ns"
            case timerCompilePrepPartial = "timer_compile_prep_partial_ns"
            case timerCompileTranslateQueries = "timer_compile_translate_queries_ns"

            case timerCompileRewriteTemplate = "timer_compile_stage_rewrite_template_strings_ns"
            case timerQueryCompileBuildComprehensionIndex = "timer_query_compile_stage_build_comprehension_index_ns"
            case timerQueryCompileCheckDeprecated = "timer_query_compile_stage_check_deprecated_builtins_ns"
            case timerQueryCompileCheckKeywords = "timer_query_compile_stage_check_keyword_overrides_ns"
            case timerQueryCompileCheckSafety = "timer_query_compile_stage_check_safety_ns"
            case timerQueryCompileCheckTypes = "timer_query_compile_stage_check_types_ns"
            case timerQueryCompileCheckUndefinedFuncs = "timer_query_compile_stage_check_undefined_funcs_ns"
            case timerQueryCompileCheckUnsafeBuiltins = "timer_query_compile_stage_check_unsafe_builtins_ns"
            case timerQueryCompileCheckVoidCalls = "timer_query_compile_stage_check_void_calls_ns"
            case timerQueryCompileResolveRefs = "timer_query_compile_stage_resolve_refs_ns"
            case timerQueryCompileRewriteComprehensionTerms = "timer_query_compile_stage_rewrite_comprehension_terms_ns"
            case timerQueryCompileRewriteDynamicTerms = "timer_query_compile_stage_rewrite_dynamic_terms_ns"
            case timerQueryCompileRewriteEquals = "timer_query_compile_stage_rewrite_equals_ns"
            case timerQueryCompileRewriteExprTerms = "timer_query_compile_stage_rewrite_expr_terms_ns"
            case timerQueryCompileRewriteLocalVars = "timer_query_compile_stage_rewrite_local_vars_ns"
            case timerQueryCompileRewritePrintCalls = "timer_query_compile_stage_rewrite_print_calls_ns"
            case timerQueryCompileRewriteWithValues = "timer_query_compile_stage_rewrite_with_values_ns"

            case timerEvalOpPlug = "timer_eval_op_plug_ns"
            case timerEvalOpResolve = "timer_eval_op_resolve_ns"
            case timerEvalOpRuleIndex = "timer_eval_op_rule_index_ns"
            case timerPartialOpCopyPropagation = "timer_partial_op_copy_propagation_ns"
            case timerPartialOpSaveSetContains = "timer_partial_op_save_set_contains_ns"
            case timerPartialOpSaveUnify = "timer_partial_op_save_unify_ns"

            case counterServerQueryCacheHit = "counter_server_query_cache_hit"
            case counterEvalOpBaseCacheMiss = "counter_eval_op_base_cache_miss"

            case histogramEvalOpPlug = "histogram_eval_op_plug"
            case histogramEvalOpResolve = "histogram_eval_op_resolve"
            case histogramEvalOpRuleIndex = "histogram_eval_op_rule_index"
            case histogramPartialOpCopyPropagation = "histogram_partial_op_copy_propagation"
            case histogramPartialOpSaveSetContains = "histogram_partial_op_save_set_contains"
            case histogramPartialOpSaveUnify = "histogram_partial_op_save_unify"
        }

        public struct Instrument: Codable, Hashable, Sendable {
            let percentage75: Double
            let percentage90: Double
            let percentage95: Double
            let percentage99: Double
            let percentage99_9: Double
            let percentage99_99: Double
            let count: Int64
            let max: Double
            let mean: Double
            let median: Double
            let min: Double
            let stddev: Double

            enum CodingKeys: String, CodingKey {
                case percentage75 = "75%"
                case percentage90 = "90%"
                case percentage95 = "95%"
                case percentage99 = "99%"
                case percentage99_9 = "99.9%"
                case percentage99_99 = "99.99%"
                case count, max, mean, median, min, stddev
            }
        }
    }
}

extension OPA.Metrics: Loggerable, CustomStringConvertible {
    public var description: String {
        var lines: [String] = []

        // 核心辅助：通过 CodingKey 动态获取原始 Key 名，并自动处理单位转换
        func addLine<T>(_ key: CodingKeys, _ value: T?) {
            guard let value = value else { return }
            let label = key.stringValue
            
            // 自动识别计时器并转为 ms，其他类型保持原样
            if let ns = value as? Int64, label.hasSuffix("_ns") {
                lines.append("\(label): \(Double(ns) / 1_000_000.0)ms")
            } else {
                lines.append("\(label): \(value)")
            }
        }

        // --- 第一梯队：最常用核心指标 (Top Priority) ---
        addLine(.timerServerHandler, timerServerHandler)
        addLine(.timerRegoQueryEval, timerRegoQueryEval)
        addLine(.timerRegoPartialEval, timerRegoPartialEval)
        addLine(.counterServerQueryCacheHit, counterServerQueryCacheHit)
        addLine(.counterEvalOpBaseCacheMiss, counterEvalOpBaseCacheMiss)
        addLine(.timerRegoQueryParse, timerRegoQueryParse)
        addLine(.timerRegoQueryCompile, timerRegoQueryCompile)

        // --- 第二梯队：编译与转换摘要 (Compile & Translate) ---
        addLine(.timerCompileEvalConstraints, timerCompileEvalConstraints)
        addLine(.timerCompilePrepPartial, timerCompilePrepPartial)
        addLine(.timerCompileTranslateQueries, timerCompileTranslateQueries)
        addLine(.timerRegoInputParse, timerRegoInputParse)
        addLine(.timerRegoExternalResolve, timerRegoExternalResolve)

        // --- 第三梯队：原子操作级计时 (Op Timers) ---
        addLine(.timerEvalOpRuleIndex, timerEvalOpRuleIndex)
        addLine(.timerEvalOpResolve, timerEvalOpResolve)
        addLine(.timerEvalOpPlug, timerEvalOpPlug)
        addLine(.timerPartialOpCopyPropagation, timerPartialOpCopyPropagation)
        addLine(.timerPartialOpSaveSetContains, timerPartialOpSaveSetContains)
        addLine(.timerPartialOpSaveUnify, timerPartialOpSaveUnify)

        // --- 第四梯队：细分编译阶段 (Compile Stages) ---
        addLine(.timerCompileRewriteTemplate, timerCompileRewriteTemplate)
        addLine(.timerQueryCompileBuildComprehensionIndex, timerQueryCompileBuildComprehensionIndex)
        addLine(.timerQueryCompileCheckSafety, timerQueryCompileCheckSafety)
        addLine(.timerQueryCompileCheckTypes, timerQueryCompileCheckTypes)
        addLine(.timerQueryCompileResolveRefs, timerQueryCompileResolveRefs)
        addLine(.timerQueryCompileRewriteLocalVars, timerQueryCompileRewriteLocalVars)
        addLine(.timerQueryCompileRewriteEquals, timerQueryCompileRewriteEquals)
        // ... (此处可按需补全剩余的细分 timer)

        // --- 第五梯队：全量采样数据 (Histograms) ---
        addHistograms(&lines)

        return lines.joined(separator: "\n")
    }

    private func addHistograms(_ lines: inout [String]) {
        func addH(_ key: CodingKeys, _ inst: Instrument?) {
            guard let inst = inst else { return }
            lines.append("\(key.stringValue): {\(inst)}")
        }
        addH(.histogramEvalOpRuleIndex, histogramEvalOpRuleIndex)
        addH(.histogramEvalOpResolve, histogramEvalOpResolve)
        addH(.histogramEvalOpPlug, histogramEvalOpPlug)
        addH(.histogramPartialOpCopyPropagation, histogramPartialOpCopyPropagation)
        addH(.histogramPartialOpSaveSetContains, histogramPartialOpSaveSetContains)
        addH(.histogramPartialOpSaveUnify, histogramPartialOpSaveUnify)
    }
}

extension OPA.Metrics.Instrument: Loggerable, CustomStringConvertible {
    public var description: String {
        // 直方图全量展开为一行
        return "n:\(count), min:\(min), max:\(max), avg:\(mean), p75:\(percentage75), p90:\(percentage90), p95:\(percentage95), p99:\(percentage99)"
    }
}
