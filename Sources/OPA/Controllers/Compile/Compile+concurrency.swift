public extension OPA.CompileController {
    func partial<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    > (
        query: String,
        input: G?,
        options: PartialOption = .init(),
        unknowns: [String],
        as type: T.Type = PartialResult.self,
        parameter: QueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await partial(
            query: query,
            input: input,
            options: options,
            unknowns: unknowns,
            as: type,
            parameter: parameter
        ).get()
    }
    
    func uCastDataFilter<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        path: String,
        input: G,
        target: TargetDialect.UCAST,
        options: UCASTTargetDataFilterOption = .init(),
        unknowns: [String],
        parameter: QueryParameter = .init(),
        as type: T.Type = UCASTTargetResult.self
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await uCastDataFilter(
            path: path,
            input: input,
            target: target,
            options: options,
            unknowns: unknowns,
            parameter: parameter,
            as: type
        ).get()
    }
    
    func sqlDataFilter<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        path: String,
        input: G,
        target: TargetDialect.SQL,
        options: SQLTargetDataFilterOption = .init(),
        unknowns: [String],
        parameter: QueryParameter = .init(),
        as type: T.Type = SQLTargetResult.self
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await sqlDataFilter(
            path: path,
            input: input,
            target: target,
            options: options,
            unknowns: unknowns,
            parameter: parameter,
            as: type
        ).get()
    }
    
    func dataFilter<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        path: String,
        input: G,
        options: MultiTargetDataFilterOption = .init(),
        unknowns: [String],
        parameter: QueryParameter = .init(),
        as type: T.Type = MultiTargetResult.self
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await dataFilter(
            path: path,
            input: input,
            options: options,
            unknowns: unknowns,
            parameter: parameter,
            as: type
        ).get()
    }
}
