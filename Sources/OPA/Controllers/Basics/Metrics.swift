import NIOAdvanced
import Foundation
@preconcurrency import AnyCodable

public extension OPA {
    /// OPA 性能度量指标
    struct Metrics: Decodable, Sendable {
        
        // MARK: - 核心流程计时器 (Core Timers)
        
        /// 输入数据解析耗时 (ns)。解析请求体中 `input` JSON 字段的时间。
        public let timerRegoInputParse: Int64?
        /// 查询解析耗时 (ns)。解析 Rego 查询语句（如 URL 中的路径或 Body 中的 query）的时间。
        public let timerRegoQueryParse: Int64?
        /// 查询编译耗时 (ns)。将解析后的 AST 编译为可执行规则的时间。
        public let timerRegoQueryCompile: Int64?
        /// 查询评估/执行耗时 (ns)。**核心指标**，表示实际执行策略评估算法的时间。
        public let timerRegoQueryEval: Int64?
        /// 模块解析耗时 (ns)。解析传入的 Rego 策略源码文件的时间。
        public let timerRegoModuleParse: Int64?
        /// 模块编译耗时 (ns)。对解析后的模块进行类型检查、安全检查并编译为索引的时间。
        public let timerRegoModuleCompile: Int64?
        /// 服务器总处理耗时 (ns)。从接收 HTTP 请求到准备发送响应的全过程耗时。
        public let timerServerHandler: Int64?
        /// 服务器读取字节耗时 (ns)。从 Socket 读取请求原始数据的时间。
        public let timerServerReadBytes: Int64?
        /// 外部引用解析耗时 (ns)。在评估过程中解析 `data` 引用的时间。
        public let timerRegoExternalResolve: Int64?
        /// 部分求值耗时 (ns)。执行部分求值（Partial Evaluation）逻辑的时间。
        public let timerRegoPartialEval: Int64?
        
        // MARK: - RegoVM 计时器 (Virtual Machine)
        
        /// Rego 虚拟机执行耗时 (ns)。当使用 Wasm 或新式 VM 引擎时，表示在虚拟机内执行指令的时间。
        public let timerRegovmEval: Int64?

        // MARK: - 编译转换计时器 (Compile/Translate Timers)
        
        /// 评估约束条件耗时 (ns)。在编译 API 中处理下推约束的时间。
        public let timerCompileEvalConstraints: Int64?
        /// 准备部分求值阶段耗时 (ns)。
        public let timerCompilePrepPartial: Int64?
        /// 查询翻译耗时 (ns)。将 Rego 逻辑翻译为其他形式（如 SQL）的时间。
        public let timerCompileTranslateQueries: Int64?

        // MARK: - 细分阶段计时器 (Compile Stages)
        
        /// 重写模板字符串阶段耗时 (ns)。
        public let timerCompileRewriteTemplate: Int64?
        /// 构建推导式索引阶段耗时 (ns)。针对 `[x | ...]` 逻辑构建加速索引的时间。
        public let timerQueryCompileBuildComprehensionIndex: Int64?
        /// 检查弃用函数阶段耗时 (ns)。
        public let timerQueryCompileCheckDeprecated: Int64?
        /// 检查关键字覆盖阶段耗时 (ns)。
        public let timerQueryCompileCheckKeywords: Int64?
        /// 安全检查阶段耗时 (ns)。验证变量是否已赋值，是否存在死循环风险。
        public let timerQueryCompileCheckSafety: Int64?
        /// 类型检查阶段耗时 (ns)。
        public let timerQueryCompileCheckTypes: Int64?
        /// 检查未定义函数阶段耗时 (ns)。
        public let timerQueryCompileCheckUndefinedFuncs: Int64?
        /// 检查不安全内置函数阶段耗时 (ns)。
        public let timerQueryCompileCheckUnsafeBuiltins: Int64?
        /// 检查空/无效调用阶段耗时 (ns)。
        public let timerQueryCompileCheckVoidCalls: Int64?
        /// 解析引用阶段耗时 (ns)。将相对路径引用解析为绝对路径的时间。
        public let timerQueryCompileResolveRefs: Int64?
        /// 重写推导式项阶段耗时 (ns)。
        public let timerQueryCompileRewriteComprehensionTerms: Int64?
        /// 重写动态项阶段耗时 (ns)。
        public let timerQueryCompileRewriteDynamicTerms: Int64?
        /// 重写等式/赋值项阶段耗时 (ns)。
        public let timerQueryCompileRewriteEquals: Int64?
        /// 重写表达式项阶段耗时 (ns)。
        public let timerQueryCompileRewriteExprTerms: Int64?
        /// 重写局部变量阶段耗时 (ns)。
        public let timerQueryCompileRewriteLocalVars: Int64?
        /// 重写 Print 调用阶段耗时 (ns)。
        public let timerQueryCompileRewritePrintCalls: Int64?
        /// 重写 With 语句值阶段耗时 (ns)。
        public let timerQueryCompileRewriteWithValues: Int64?

        // MARK: - 操作级计时器 (Op Timers)
        
        /// 评估插件操作耗时 (ns)。
        public let timerEvalOpPlug: Int64?
        /// 评估解析操作耗时 (ns)。
        public let timerEvalOpResolve: Int64?
        /// 规则索引匹配耗时 (ns)。在大量规则中根据输入寻找匹配项的时间。
        public let timerEvalOpRuleIndex: Int64?
        /// 内置函数调用耗时 (ns)。执行如 `http.send` 或 `crypto.sha256` 等函数的时间。
        public let timerEvalOpBuiltinCall: Int64?
        /// 部分求值：副本传播操作耗时 (ns)。
        public let timerPartialOpCopyPropagation: Int64?
        /// 部分求值：集合成员检查耗时 (ns)。
        public let timerPartialOpSaveSetContains: Int64?
        /// 部分求值：递归集合成员检查耗时 (ns)。
        public let timerPartialOpSaveSetContainsRec: Int64?
        /// 部分求值：统一化（Unify）保存操作耗时 (ns)。
        public let timerPartialOpSaveUnify: Int64?

        // MARK: - 计数器 (Counters)
        
        /// 服务器查询缓存命中次数。
        public let counterServerQueryCacheHit: Int64?
        /// 评估操作基础缓存未命中次数。
        public let counterEvalOpBaseCacheMiss: Int64?
        /// 评估操作基础缓存命中次数。
        public let counterEvalOpBaseCacheHit: Int64?
        /// 虚拟缓存未命中次数。
        public let counterEvalOpVirtualCacheMiss: Int64?
        /// Rego 虚拟机执行的指令总数。
        public let counterRegovmEvalInstructions: Int64?
        /// Rego 虚拟机虚拟缓存命中次数。
        public let counterRegovmVirtualCacheHits: Int64?
        /// Rego 虚拟机虚拟缓存未命中次数。
        public let counterRegovmVirtualCacheMisses: Int64?

        // MARK: - 直方图 (Histograms)
        
        /// Eval Plug 操作的耗时统计分布。
        public let histogramEvalOpPlug: Instrument?
        /// Eval Resolve 操作的耗时统计分布。
        public let histogramEvalOpResolve: Instrument?
        /// Eval Rule Index 操作的耗时统计分布。
        public let histogramEvalOpRuleIndex: Instrument?
        /// 内置函数调用的耗时统计分布。
        public let histogramEvalOpBuiltinCall: Instrument?
        /// Partial Copy Propagation 操作的耗时统计分布。
        public let histogramPartialOpCopyPropagation: Instrument?
        /// Partial Save Set Contains 操作的耗时统计分布。
        public let histogramPartialOpSaveSetContains: Instrument?
        /// 递归式集合成员检查的耗时统计分布。
        public let histogramPartialOpSaveSetContainsRec: Instrument?
        /// Partial Save Unify 操作的耗时统计分布。
        public let histogramPartialOpSaveUnify: Instrument?

        /// 存储 JSON 中存在但模型未定义的字段，用于自动发现 OPA 的新指标。
        public let unknownFields: [String: AnyCodable]

        enum CodingKeys: String, CodingKey, CaseIterable {
            case timerRegoInputParse = "timer_rego_input_parse_ns"
            case timerRegoQueryParse = "timer_rego_query_parse_ns"
            case timerRegoQueryCompile = "timer_rego_query_compile_ns"
            case timerRegoQueryEval = "timer_rego_query_eval_ns"
            case timerRegoModuleParse = "timer_rego_module_parse_ns"
            case timerRegoModuleCompile = "timer_rego_module_compile_ns"
            case timerServerHandler = "timer_server_handler_ns"
            case timerServerReadBytes = "timer_server_read_bytes_ns"
            case timerRegoExternalResolve = "timer_rego_external_resolve_ns"
            case timerRegoPartialEval = "timer_rego_partial_eval_ns"
            case timerRegovmEval = "timer_regovm_eval_ns"
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
            case timerEvalOpBuiltinCall = "timer_eval_op_builtin_call_ns"
            case timerPartialOpCopyPropagation = "timer_partial_op_copy_propagation_ns"
            case timerPartialOpSaveSetContains = "timer_partial_op_save_set_contains_ns"
            case timerPartialOpSaveSetContainsRec = "timer_partial_op_save_set_contains_rec_ns"
            case timerPartialOpSaveUnify = "timer_partial_op_save_unify_ns"
            case counterServerQueryCacheHit = "counter_server_query_cache_hit"
            case counterEvalOpBaseCacheMiss = "counter_eval_op_base_cache_miss"
            case counterEvalOpBaseCacheHit = "counter_eval_op_base_cache_hit"
            case counterEvalOpVirtualCacheMiss = "counter_eval_op_virtual_cache_miss"
            case counterRegovmEvalInstructions = "counter_regovm_eval_instructions"
            case counterRegovmVirtualCacheHits = "counter_regovm_virtual_cache_hits"
            case counterRegovmVirtualCacheMisses = "counter_regovm_virtual_cache_misses"
            case histogramEvalOpPlug = "histogram_eval_op_plug"
            case histogramEvalOpResolve = "histogram_eval_op_resolve"
            case histogramEvalOpRuleIndex = "histogram_eval_op_rule_index"
            case histogramEvalOpBuiltinCall = "histogram_eval_op_builtin_call"
            case histogramPartialOpCopyPropagation = "histogram_partial_op_copy_propagation"
            case histogramPartialOpSaveSetContains = "histogram_partial_op_save_set_contains"
            case histogramPartialOpSaveSetContainsRec = "histogram_partial_op_save_set_contains_rec"
            case histogramPartialOpSaveUnify = "histogram_partial_op_save_unify"
        }

        struct DynamicKey: CodingKey {
            var stringValue: String
            init?(stringValue: String) { self.stringValue = stringValue }
            var intValue: Int? { nil }
            init?(intValue: Int) { nil }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)

            self.timerRegoInputParse = try container.decodeIfPresent(Int64.self, forKey: .timerRegoInputParse)
            self.timerRegoQueryParse = try container.decodeIfPresent(Int64.self, forKey: .timerRegoQueryParse)
            self.timerRegoQueryCompile = try container.decodeIfPresent(Int64.self, forKey: .timerRegoQueryCompile)
            self.timerRegoQueryEval = try container.decodeIfPresent(Int64.self, forKey: .timerRegoQueryEval)
            self.timerRegoModuleParse = try container.decodeIfPresent(Int64.self, forKey: .timerRegoModuleParse)
            self.timerRegoModuleCompile = try container.decodeIfPresent(Int64.self, forKey: .timerRegoModuleCompile)
            self.timerServerReadBytes = try container.decodeIfPresent(Int64.self, forKey: .timerServerReadBytes)
            self.timerServerHandler = try container.decodeIfPresent(Int64.self, forKey: .timerServerHandler)
            self.timerRegoExternalResolve = try container.decodeIfPresent(Int64.self, forKey: .timerRegoExternalResolve)
            self.timerRegoPartialEval = try container.decodeIfPresent(Int64.self, forKey: .timerRegoPartialEval)
            self.timerRegovmEval = try container.decodeIfPresent(Int64.self, forKey: .timerRegovmEval)
            self.timerCompileEvalConstraints = try container.decodeIfPresent(Int64.self, forKey: .timerCompileEvalConstraints)
            self.timerCompilePrepPartial = try container.decodeIfPresent(Int64.self, forKey: .timerCompilePrepPartial)
            self.timerCompileTranslateQueries = try container.decodeIfPresent(Int64.self, forKey: .timerCompileTranslateQueries)
            self.timerCompileRewriteTemplate = try container.decodeIfPresent(Int64.self, forKey: .timerCompileRewriteTemplate)
            self.timerQueryCompileBuildComprehensionIndex = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileBuildComprehensionIndex)
            self.timerQueryCompileCheckDeprecated = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckDeprecated)
            self.timerQueryCompileCheckKeywords = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckKeywords)
            self.timerQueryCompileCheckSafety = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckSafety)
            self.timerQueryCompileCheckTypes = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckTypes)
            self.timerQueryCompileCheckUndefinedFuncs = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckUndefinedFuncs)
            self.timerQueryCompileCheckUnsafeBuiltins = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckUnsafeBuiltins)
            self.timerQueryCompileCheckVoidCalls = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileCheckVoidCalls)
            self.timerQueryCompileResolveRefs = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileResolveRefs)
            self.timerQueryCompileRewriteComprehensionTerms = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewriteComprehensionTerms)
            self.timerQueryCompileRewriteDynamicTerms = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewriteDynamicTerms)
            self.timerQueryCompileRewriteEquals = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewriteEquals)
            self.timerQueryCompileRewriteExprTerms = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewriteExprTerms)
            self.timerQueryCompileRewriteLocalVars = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewriteLocalVars)
            self.timerQueryCompileRewritePrintCalls = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewritePrintCalls)
            self.timerQueryCompileRewriteWithValues = try container.decodeIfPresent(Int64.self, forKey: .timerQueryCompileRewriteWithValues)
            self.timerEvalOpPlug = try container.decodeIfPresent(Int64.self, forKey: .timerEvalOpPlug)
            self.timerEvalOpResolve = try container.decodeIfPresent(Int64.self, forKey: .timerEvalOpResolve)
            self.timerEvalOpRuleIndex = try container.decodeIfPresent(Int64.self, forKey: .timerEvalOpRuleIndex)
            self.timerEvalOpBuiltinCall = try container.decodeIfPresent(Int64.self, forKey: .timerEvalOpBuiltinCall)
            self.timerPartialOpCopyPropagation = try container.decodeIfPresent(Int64.self, forKey: .timerPartialOpCopyPropagation)
            self.timerPartialOpSaveSetContains = try container.decodeIfPresent(Int64.self, forKey: .timerPartialOpSaveSetContains)
            self.timerPartialOpSaveSetContainsRec = try container.decodeIfPresent(Int64.self, forKey: .timerPartialOpSaveSetContainsRec)
            self.timerPartialOpSaveUnify = try container.decodeIfPresent(Int64.self, forKey: .timerPartialOpSaveUnify)
            self.counterServerQueryCacheHit = try container.decodeIfPresent(Int64.self, forKey: .counterServerQueryCacheHit)
            self.counterEvalOpBaseCacheMiss = try container.decodeIfPresent(Int64.self, forKey: .counterEvalOpBaseCacheMiss)
            self.counterEvalOpBaseCacheHit = try container.decodeIfPresent(Int64.self, forKey: .counterEvalOpBaseCacheHit)
            self.counterEvalOpVirtualCacheMiss = try container.decodeIfPresent(Int64.self, forKey: .counterEvalOpVirtualCacheMiss)
            self.counterRegovmEvalInstructions = try container.decodeIfPresent(Int64.self, forKey: .counterRegovmEvalInstructions)
            self.counterRegovmVirtualCacheHits = try container.decodeIfPresent(Int64.self, forKey: .counterRegovmVirtualCacheHits)
            self.counterRegovmVirtualCacheMisses = try container.decodeIfPresent(Int64.self, forKey: .counterRegovmVirtualCacheMisses)
            self.histogramEvalOpPlug = try container.decodeIfPresent(Instrument.self, forKey: .histogramEvalOpPlug)
            self.histogramEvalOpResolve = try container.decodeIfPresent(Instrument.self, forKey: .histogramEvalOpResolve)
            self.histogramEvalOpRuleIndex = try container.decodeIfPresent(Instrument.self, forKey: .histogramEvalOpRuleIndex)
            self.histogramEvalOpBuiltinCall = try container.decodeIfPresent(Instrument.self, forKey: .histogramEvalOpBuiltinCall)
            self.histogramPartialOpCopyPropagation = try container.decodeIfPresent(Instrument.self, forKey: .histogramPartialOpCopyPropagation)
            self.histogramPartialOpSaveSetContains = try container.decodeIfPresent(Instrument.self, forKey: .histogramPartialOpSaveSetContains)
            self.histogramPartialOpSaveSetContainsRec = try container.decodeIfPresent(Instrument.self, forKey: .histogramPartialOpSaveSetContainsRec)
            self.histogramPartialOpSaveUnify = try container.decodeIfPresent(Instrument.self, forKey: .histogramPartialOpSaveUnify)

            let dynamicContainer = try decoder.container(keyedBy: DynamicKey.self)
            var unknowns: [String: AnyCodable] = [:]
            let definedKeys = Set(CodingKeys.allCases.map { $0.stringValue })

            for key in dynamicContainer.allKeys {
                if !definedKeys.contains(key.stringValue) {
                    if let value = try? dynamicContainer.decode(AnyCodable.self, forKey: key) {
                        unknowns[key.stringValue] = value
                    }
                }
            }
            self.unknownFields = unknowns
        }

        /// 直方图采样度量模型
        public struct Instrument: Codable, Hashable, Sendable {
            public let percentage75: Double
            public let percentage90: Double
            public let percentage95: Double
            public let percentage99: Double
            public let percentage99_9: Double
            public let percentage99_99: Double
            public let count: Int64
            public let max: Double
            public let mean: Double
            public let median: Double
            public let min: Double
            public let stddev: Double

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

// --- 扩展：全量打印逻辑 ---

extension OPA.Metrics: Loggerable, CustomStringConvertible {
    public var description: String {
        var lines: [String] = []

        func processKey(_ key: CodingKeys) {
            let label = key.stringValue
            let value: Any?

            switch key {
            case .timerRegoInputParse: value = timerRegoInputParse
            case .timerRegoQueryParse: value = timerRegoQueryParse
            case .timerRegoQueryCompile: value = timerRegoQueryCompile
            case .timerRegoQueryEval: value = timerRegoQueryEval
            case .timerRegoModuleParse: value = timerRegoModuleParse
            case .timerRegoModuleCompile: value = timerRegoModuleCompile
            case .timerServerHandler: value = timerServerHandler
            case .timerServerReadBytes: value = timerServerReadBytes
            case .timerRegoExternalResolve: value = timerRegoExternalResolve
            case .timerRegoPartialEval: value = timerRegoPartialEval
            case .timerRegovmEval: value = timerRegovmEval
            case .timerCompileEvalConstraints: value = timerCompileEvalConstraints
            case .timerCompilePrepPartial: value = timerCompilePrepPartial
            case .timerCompileTranslateQueries: value = timerCompileTranslateQueries
            case .timerCompileRewriteTemplate: value = timerCompileRewriteTemplate
            case .timerQueryCompileBuildComprehensionIndex: value = timerQueryCompileBuildComprehensionIndex
            case .timerQueryCompileCheckDeprecated: value = timerQueryCompileCheckDeprecated
            case .timerQueryCompileCheckKeywords: value = timerQueryCompileCheckKeywords
            case .timerQueryCompileCheckSafety: value = timerQueryCompileCheckSafety
            case .timerQueryCompileCheckTypes: value = timerQueryCompileCheckTypes
            case .timerQueryCompileCheckUndefinedFuncs: value = timerQueryCompileCheckUndefinedFuncs
            case .timerQueryCompileCheckUnsafeBuiltins: value = timerQueryCompileCheckUnsafeBuiltins
            case .timerQueryCompileCheckVoidCalls: value = timerQueryCompileCheckVoidCalls
            case .timerQueryCompileResolveRefs: value = timerQueryCompileResolveRefs
            case .timerQueryCompileRewriteComprehensionTerms: value = timerQueryCompileRewriteComprehensionTerms
            case .timerQueryCompileRewriteDynamicTerms: value = timerQueryCompileRewriteDynamicTerms
            case .timerQueryCompileRewriteEquals: value = timerQueryCompileRewriteEquals
            case .timerQueryCompileRewriteExprTerms: value = timerQueryCompileRewriteExprTerms
            case .timerQueryCompileRewriteLocalVars: value = timerQueryCompileRewriteLocalVars
            case .timerQueryCompileRewritePrintCalls: value = timerQueryCompileRewritePrintCalls
            case .timerQueryCompileRewriteWithValues: value = timerQueryCompileRewriteWithValues
            case .timerEvalOpPlug: value = timerEvalOpPlug
            case .timerEvalOpResolve: value = timerEvalOpResolve
            case .timerEvalOpRuleIndex: value = timerEvalOpRuleIndex
            case .timerEvalOpBuiltinCall: value = timerEvalOpBuiltinCall
            case .timerPartialOpCopyPropagation: value = timerPartialOpCopyPropagation
            case .timerPartialOpSaveSetContains: value = timerPartialOpSaveSetContains
            case .timerPartialOpSaveSetContainsRec: value = timerPartialOpSaveSetContainsRec
            case .timerPartialOpSaveUnify: value = timerPartialOpSaveUnify
            case .counterServerQueryCacheHit: value = counterServerQueryCacheHit
            case .counterEvalOpBaseCacheMiss: value = counterEvalOpBaseCacheMiss
            case .counterEvalOpBaseCacheHit: value = counterEvalOpBaseCacheHit
            case .counterEvalOpVirtualCacheMiss: value = counterEvalOpVirtualCacheMiss
            case .counterRegovmEvalInstructions: value = counterRegovmEvalInstructions
            case .counterRegovmVirtualCacheHits: value = counterRegovmVirtualCacheHits
            case .counterRegovmVirtualCacheMisses: value = counterRegovmVirtualCacheMisses
            case .histogramEvalOpPlug: value = histogramEvalOpPlug
            case .histogramEvalOpResolve: value = histogramEvalOpResolve
            case .histogramEvalOpRuleIndex: value = histogramEvalOpRuleIndex
            case .histogramEvalOpBuiltinCall: value = histogramEvalOpBuiltinCall
            case .histogramPartialOpCopyPropagation: value = histogramPartialOpCopyPropagation
            case .histogramPartialOpSaveSetContains: value = histogramPartialOpSaveSetContains
            case .histogramPartialOpSaveSetContainsRec: value = histogramPartialOpSaveSetContainsRec
            case .histogramPartialOpSaveUnify: value = histogramPartialOpSaveUnify
            }

            guard let unwrapped = value else { return }

            if let ns = unwrapped as? Int64, label.hasSuffix("_ns") {
                lines.append("\(label): \(Double(ns) / 1_000_000.0)ms")
            } else if let instrument = unwrapped as? Instrument {
                lines.append("\(label): {\(instrument)}")
            } else {
                lines.append("\(label): \(unwrapped)")
            }
        }

        CodingKeys.allCases.forEach { processKey($0) }

        if !unknownFields.isEmpty {
            lines.append("--- [未知指标] ---")
            for (key, value) in unknownFields.sorted(by: { $0.key < $1.key }) {
                if key.hasSuffix("_ns"), let ns = value.value as? Int64 {
                    lines.append("\(key): \(Double(ns) / 1_000_000.0)ms")
                } else {
                    lines.append("\(key): \(value)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}

extension OPA.Metrics.Instrument: Loggerable, CustomStringConvertible {
    public var description: String {
        return "n:\(count), min:\(min), max:\(max), avg:\(mean), p99:\(percentage99)"
    }
}
