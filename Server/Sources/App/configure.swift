import Fluent
import FluentPostgresDriver
import Foundation
import JWT
import SharedModels
import Vapor

public func configure(_ app: Application) async throws {
    // 1. Configure ISO-8601 JSON coding globally
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    ContentConfiguration.global.use(encoder: encoder, for: .json)
    ContentConfiguration.global.use(decoder: decoder, for: .json)

    // 2. Configure Middleware (APIErrorMiddleware + FileMiddleware for local uploads)
    app.middleware = Middlewares()
    app.middleware.use(APIErrorMiddleware())

    let publicDir = app.directory.publicDirectory
    try? FileManager.default.createDirectory(
        atPath: publicDir + "uploads",
        withIntermediateDirectories: true
    )
    app.middleware.use(FileMiddleware(publicDirectory: publicDir))

    // Cap request body size to 10 MB to prevent oversized upload DoS
    app.routes.defaultMaxBodySize = "10mb"

    // 3. Configure PostgreSQL Database
    let dbHost = Environment.get("DATABASE_HOST") ?? "127.0.0.1"
    let dbPort = Environment.get("DATABASE_PORT").flatMap(Int.init) ?? SQLPostgresConfiguration.ianaPortNumber
    let dbUser = Environment.get("DATABASE_USERNAME") ?? "postgres"
    let dbPassword = Environment.get("DATABASE_PASSWORD") ?? "postgres"
    let defaultDBName = app.environment == .testing ? "stallion_match_test" : "stallion_match"
    let dbName: String
    if app.environment == .testing {
        dbName = Environment.get("DATABASE_TEST_NAME") ?? defaultDBName
    } else {
        dbName = Environment.get("DATABASE_NAME") ?? defaultDBName
    }

    let postgresConfig = SQLPostgresConfiguration(
        hostname: dbHost,
        port: dbPort,
        username: dbUser,
        password: dbPassword,
        database: dbName,
        tls: .disable
    )
    app.databases.use(.postgres(configuration: postgresConfig), as: .psql)

    // 4. Register Reversible Migrations
    app.migrations.add(CreateInitialSchema())
    if Environment.get("AUTO_MIGRATE") != "false" {
        try await app.autoMigrate()
    }

    // 5. Configure JWT Signer
    let jwtSecret = Environment.get("JWT_SECRET") ?? "stallion-match-local-development-secret-key-2026"
    app.jwt.signers.use(.hs256(key: jwtSecret))

    // 6. Configure StorageService ("local" or "s3")
    let storageDriver = (Environment.get("STORAGE_DRIVER") ?? "local").lowercased()
    let publicBaseURL = Environment.get("PUBLIC_BASE_URL") ?? "http://127.0.0.1:\(app.http.server.configuration.port)"
    if storageDriver == "s3",
        let endpoint = Environment.get("S3_ENDPOINT"),
        let bucket = Environment.get("S3_BUCKET"),
        let region = Environment.get("S3_REGION"),
        let accessKeyID = Environment.get("S3_ACCESS_KEY_ID"),
        let secretAccessKey = Environment.get("S3_SECRET_ACCESS_KEY"),
        !accessKeyID.isEmpty,
        !secretAccessKey.isEmpty
    {
        app.storageService = S3CompatibleStorageService(
            endpoint: endpoint,
            bucket: bucket,
            region: region,
            accessKeyID: accessKeyID,
            secretAccessKey: secretAccessKey,
            client: app.client
        )
    } else {
        let localPath = Environment.get("LOCAL_STORAGE_PATH") ?? (publicDir + "uploads")
        app.storageService = LocalDiskStorageService(
            baseDirectory: localPath,
            publicBaseURL: publicBaseURL
        )
    }

    // 7. Configure PushNotificationService ("stub" or "apns")
    let apnsDriver = (Environment.get("APNS_DRIVER") ?? "stub").lowercased()
    if apnsDriver == "apns",
        let keyID = Environment.get("APNS_KEY_ID"),
        let teamID = Environment.get("APNS_TEAM_ID"),
        let topic = Environment.get("APNS_TOPIC"),
        let keyPath = Environment.get("APNS_PRIVATE_KEY_PATH"),
        let pem = try? String(contentsOfFile: keyPath, encoding: .utf8)
    {
        let isProd = (Environment.get("APNS_ENVIRONMENT") ?? "sandbox").lowercased() == "production"
        app.pushNotificationService = APNsPushNotificationService(
            keyID: keyID,
            teamID: teamID,
            topic: topic,
            privateKeyPEM: pem,
            isProduction: isProd,
            client: app.client,
            logger: app.logger
        )
    } else {
        app.pushNotificationService = StubPushNotificationService(logger: app.logger)
    }

    // 8. Configure Server Host/Port
    if let host = Environment.get("HOST") {
        app.http.server.configuration.hostname = host
    }
    if let port = Environment.get("PORT").flatMap(Int.init) {
        app.http.server.configuration.port = port
    }

    // 9. Register Routes
    try routes(app)
}
