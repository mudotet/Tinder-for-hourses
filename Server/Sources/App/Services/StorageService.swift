import Crypto
import Foundation
import SharedModels
import Vapor

public struct StoredObject: Sendable, Equatable {
    public let key: String
    public let publicURL: String

    public init(key: String, publicURL: String) {
        self.key = key
        self.publicURL = publicURL
    }
}

public protocol StorageService: Sendable {
    func uploadFile(key: String, data: Data, contentType: String) async throws -> StoredObject
    func deleteFile(key: String) async throws
}

/// Local-disk implementation of `StorageService` used during local development and automated tests.
public struct LocalDiskStorageService: StorageService, Sendable {
    public let baseDirectory: String
    public let publicBaseURL: String

    public init(baseDirectory: String, publicBaseURL: String) {
        self.baseDirectory = baseDirectory
        self.publicBaseURL = publicBaseURL.hasSuffix("/")
            ? String(publicBaseURL.dropLast())
            : publicBaseURL
    }

    public func uploadFile(key: String, data: Data, contentType: String) async throws -> StoredObject {
        let sanitizedKey = Self.sanitizeKey(key)
        let destinationURL = URL(fileURLWithPath: baseDirectory).appendingPathComponent(sanitizedKey)
        let directoryURL = destinationURL.deletingLastPathComponent()

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: destinationURL, options: .atomic)

        let publicURL = "\(publicBaseURL)/uploads/\(sanitizedKey)"
        return StoredObject(key: sanitizedKey, publicURL: publicURL)
    }

    public func deleteFile(key: String) async throws {
        let sanitizedKey = Self.sanitizeKey(key)
        let destinationURL = URL(fileURLWithPath: baseDirectory).appendingPathComponent(sanitizedKey)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
    }

    private static func sanitizeKey(_ key: String) -> String {
        key.replacingOccurrences(of: "..", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

/// S3-compatible object storage implementation using AWS Signature Version 4 over HTTP.
/// Swappable via `STORAGE_DRIVER=s3` in configuration.
public struct S3CompatibleStorageService: StorageService, Sendable {
    public let endpoint: String
    public let bucket: String
    public let region: String
    public let accessKeyID: String
    public let secretAccessKey: String
    public let client: any Client

    public init(
        endpoint: String,
        bucket: String,
        region: String,
        accessKeyID: String,
        secretAccessKey: String,
        client: any Client
    ) {
        self.endpoint = endpoint.hasSuffix("/") ? String(endpoint.dropLast()) : endpoint
        self.bucket = bucket
        self.region = region
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.client = client
    }

    public func uploadFile(key: String, data: Data, contentType: String) async throws -> StoredObject {
        let cleanKey = key.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let objectURLString = "\(endpoint)/\(bucket)/\(cleanKey)"
        let headers = try makeSignedHeaders(
            method: "PUT",
            path: "/\(bucket)/\(cleanKey)",
            payload: data,
            contentType: contentType
        )

        let response = try await client.put(URI(string: objectURLString), headers: headers) { req in
            req.body = ByteBuffer(data: data)
        }
        guard (200..<300).contains(response.status.code) else {
            throw AppError(
                .badGateway,
                code: .internalError,
                message: "S3 upload failed with HTTP status \(response.status.code)."
            )
        }
        return StoredObject(key: cleanKey, publicURL: objectURLString)
    }

    public func deleteFile(key: String) async throws {
        let cleanKey = key.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let objectURLString = "\(endpoint)/\(bucket)/\(cleanKey)"
        let headers = try makeSignedHeaders(
            method: "DELETE",
            path: "/\(bucket)/\(cleanKey)",
            payload: Data(),
            contentType: nil
        )
        _ = try await client.delete(URI(string: objectURLString), headers: headers)
    }

    private func makeSignedHeaders(
        method: String,
        path: String,
        payload: Data,
        contentType: String?
    ) throws -> HTTPHeaders {
        guard let host = URL(string: endpoint)?.host else {
            throw AppError(.internalServerError, code: .internalError, message: "Invalid S3 endpoint URL.")
        }

        let now = Date()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let amzDate = Self.amzTimestamp(from: now)
        let dateStamp = String(amzDate.prefix(8))
        let payloadHash = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()

        var headers = HTTPHeaders()
        headers.replaceOrAdd(name: .host, value: host)
        headers.replaceOrAdd(name: "x-amz-date", value: amzDate)
        headers.replaceOrAdd(name: "x-amz-content-sha256", value: payloadHash)
        if let contentType {
            headers.replaceOrAdd(name: .contentType, value: contentType)
        }

        let canonicalHeaders = "host:\(host)\nx-amz-content-sha256:\(payloadHash)\nx-amz-date:\(amzDate)\n"
        let signedHeaders = "host;x-amz-content-sha256;x-amz-date"
        let canonicalRequest = [
            method,
            path,
            "",
            canonicalHeaders,
            signedHeaders,
            payloadHash
        ].joined(separator: "\n")

        let credentialScope = "\(dateStamp)/\(region)/s3/aws4_request"
        let canonicalRequestHash = SHA256.hash(data: Data(canonicalRequest.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        let stringToSign = [
            "AWS4-HMAC-SHA256",
            amzDate,
            credentialScope,
            canonicalRequestHash
        ].joined(separator: "\n")

        let kDate = Self.hmacSHA256(key: Data("AWS4\(secretAccessKey)".utf8), data: Data(dateStamp.utf8))
        let kRegion = Self.hmacSHA256(key: kDate, data: Data(region.utf8))
        let kService = Self.hmacSHA256(key: kRegion, data: Data("s3".utf8))
        let kSigning = Self.hmacSHA256(key: kService, data: Data("aws4_request".utf8))
        let signature = Self.hmacSHA256(key: kSigning, data: Data(stringToSign.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        let authorization =
            "AWS4-HMAC-SHA256 Credential=\(accessKeyID)/\(credentialScope), SignedHeaders=\(signedHeaders), Signature=\(signature)"
        headers.replaceOrAdd(name: .authorization, value: authorization)
        return headers
    }

    private static func hmacSHA256(key: Data, data: Data) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(mac)
    }

    private static func amzTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter.string(from: date)
    }
}

public struct StorageServiceKey: StorageKey {
    public typealias Value = any StorageService
}

extension Application {
    public var storageService: any StorageService {
        get {
            if let existing = storage[StorageServiceKey.self] {
                return existing
            }
            let defaultPath = directory.publicDirectory + "uploads"
            let publicBaseURL = Environment.get("PUBLIC_BASE_URL") ?? "http://127.0.0.1:8080"
            let local = LocalDiskStorageService(baseDirectory: defaultPath, publicBaseURL: publicBaseURL)
            storage[StorageServiceKey.self] = local
            return local
        }
        set {
            storage[StorageServiceKey.self] = newValue
        }
    }
}
