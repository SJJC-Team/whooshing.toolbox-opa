@preconcurrency import AnyCodable

public extension OPA.QueryController {
    func simple<T: Decodable & Sendable>(
        input: [String: AnyCodable],
        to returnType: T.Type = [String: AnyCodable].self,
        parameter: SimpleQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> T {
        try await simple(
            input: input,
            to: returnType,
            parameter: parameter
        ).get()
    }
    
    func simple<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        input: G,
        as type: G.Type,
        to returnType: T.Type = [String: AnyCodable].self,
        parameter: SimpleQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> T {
        try await simple(
            input: input,
            as: type,
            to: returnType,
            parameter: parameter
        ).get()
    }
    
    func data<T: Decodable & Sendable>(
        from path: String,
        input: [String: AnyCodable],
        to returnType: T.Type = [String: AnyCodable].self,
        parameter: DataQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await data(
            from: path,
            input: input,
            to: returnType,
            parameter: parameter
        ).get()
    }
    
    func data<T: Encodable & Sendable, G: Decodable & Sendable>(
        from path: String,
        input: T,
        as type: T.Type,
        to returnType: G.Type = [String: AnyCodable].self,
        parameter: DataQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<G?> {
        try await data(
            from: path,
            input: input,
            as: type,
            to: returnType,
            parameter: parameter
        ).get()
    }
    
    func adhoc<T: Decodable & Sendable>(
        query: String,
        input: [String: AnyCodable],
        to returnType: T.Type = [String: AnyCodable].self,
        parameter: AdhocQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await adhoc(
            query: query,
            input: input,
            to: returnType,
            parameter: parameter
        ).get()
    }
    
    func adhoc<
        G: Encodable & Sendable,
        T: Decodable & Sendable
    >(
        query: String,
        input: G,
        as type: G.Type,
        to returnType: T.Type = [String: AnyCodable].self,
        parameter: AdhocQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<T?> {
        try await adhoc(
            query: query,
            input: input,
            as: type,
            to: returnType,
            parameter: parameter
        ).get()
    }
}
