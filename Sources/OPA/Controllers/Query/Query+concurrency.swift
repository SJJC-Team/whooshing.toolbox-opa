public extension OPA.QueryController {
    func simple<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        input: G,
        as type: T.Type = T.self,
        parameter: SimpleQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> T {
        try await simple(
            input: input,
            as: type,
            parameter: parameter
        ).get()
    }
    
    
    func data<T: Encodable & Sendable, G: Decodable & Sendable>(
        from path: String,
        input: T,
        as type: G.Type = G.self,
        parameter: DataQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<G?> {
        try await data(
            from: path,
            input: input,
            as: type,
            parameter: parameter
        ).get()
    }
    
    
    func adhoc<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        query: String,
        input: G,
        as type: T.Type = T.self,
        parameter: AdhocQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await adhoc(
            query: query,
            input: input,
            as: type,
            parameter: parameter
        ).get()
    }
}
