import Foundation
import SharedModels
import Vapor

extension Request {
    public func validateJSON(_ configure: (inout Validations) -> Void) throws {
        var validations = Validations()
        configure(&validations)
        try validations.validate(request: self).assert()
    }

    public func decodeJSON<T: Decodable>(_ type: T.Type) throws -> T {
        try content.decode(type)
    }

    public func encodeJSON<T: Encodable>(
        _ value: T,
        status: HTTPResponseStatus = .ok
    ) throws -> Response {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        let response = Response(status: status)
        response.body = .init(data: data)
        response.headers.replaceOrAdd(name: .contentType, value: "application/json; charset=utf-8")
        return response
    }
}
