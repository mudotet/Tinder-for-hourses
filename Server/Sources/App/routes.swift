import SharedModels
import Vapor

public func routes(_ app: Application) throws {
    app.get("health") { req in
        try req.encodeJSON(StatusResponse(status: "ok", message: "Stallion Match API is healthy"))
    }

    let apiV1 = app.grouped("api", "v1")
    apiV1.get("health") { req in
        try req.encodeJSON(StatusResponse(status: "ok", message: "Stallion Match API v1"))
    }

    try apiV1.register(collection: AuthController())
}
