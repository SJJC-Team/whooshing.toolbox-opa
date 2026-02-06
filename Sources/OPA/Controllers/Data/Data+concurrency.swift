public extension OPA.DataController {
    @discardableResult
    func save<T: Encodable & Sendable>(
        on path: String,
        ifNoneMatch: String? = "*",
        data: T,
        parameter: SaveQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<Bool> {
        try await save(
            on: path,
            ifNoneMatch: ifNoneMatch,
            data: data,
            parameter: parameter
        ).get()
    }
    
    @discardableResult
    func delete(
        of path: String,
        parameter: DeleteQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<OPA.NULL> {
        try await delete(
            of: path,
            parameter: parameter
        ).get()
    }
    
    @discardableResult
    func patch(
        to path: String,
        operations: [OPA.PatchOperation]
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<OPA.NULL> {
        try await patch(
            to: path,
            operations: operations
        ).get()
    }
    
    func list<G: Decodable & Sendable>(
        as type: G.Type = G.self,
        parameter: GetQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<G> {
        try await list(
            as: type,
            parameter: parameter
        ).get()
    }
    
    func get<G: Decodable & Sendable>(
        from path: String,
        as type: G.Type = G.self,
        parameter: GetQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<G?> {
        try await get(
            from: path,
            as: type,
            parameter: parameter
        ).get()
    }
}
