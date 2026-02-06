public extension OPA.PolicyController {
    @discardableResult
    func save(
        by id: String,
        content: String,
        parameter: SaveQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<OPA.NULL> {
        try await save(
            by: id,
            content: content,
            parameter: parameter
        ).get()
    }
    
    @discardableResult
    func delete(
        of id: String,
        parameter: DeleteQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<OPA.NULL> {
        try await delete(
            of: id,
            parameter: parameter
        ).get()
    }
    
    func get<T: Decodable & Sendable>(
        at id: String,
        as type: T.Type = T.self,
        parameter: GetQueryParameter = .init()
    ) async throws(OPA.Errcase.ErrType) -> PolicyAnswer<T> {
        try await get(
            at: id,
            as: type,
            parameter: parameter
        ).get()
    }
    
    func list<T: Decodable & Sendable>(
        as type: T.Type = T.self
    ) async throws(OPA.Errcase.ErrType) -> OPA.Answer<[PolicyResult<T>]> {
        try await list(
            as: type
        ).get()
    }
}
