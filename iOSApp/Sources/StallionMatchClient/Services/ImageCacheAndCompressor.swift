import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageCompressor {
    /// Downsamples and compresses image data to JPEG before uploading to the server.
    public static func compressToJPEG(
        _ inputData: Data,
        maxDimension: CGFloat = 1400,
        compressionQuality: CGFloat = 0.78
    ) -> Data {
        guard let source = CGImageSourceCreateWithData(inputData as CFData, nil) else {
            return inputData
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(maxDimension)
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return inputData
        }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return inputData
        }

        let destProps: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, destProps as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return inputData
        }
        return mutableData as Data
    }
}

/// Thread-safe image data cache backed by `URLCache` and an in-memory cache.
public actor ImageCache {
    public static let shared = ImageCache()

    private var memoryCache: [URL: Data] = [:]
    private let urlCache: URLCache

    public init(
        memoryCapacity: Int = 32 * 1024 * 1024,
        diskCapacity: Int = 128 * 1024 * 1024
    ) {
        self.urlCache = URLCache(
            memoryCapacity: memoryCapacity,
            diskCapacity: diskCapacity
        )
    }

    public func loadImageData(from url: URL) async throws -> Data {
        if let cached = memoryCache[url] {
            return cached
        }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        if let cachedResponse = urlCache.cachedResponse(for: request) {
            memoryCache[url] = cachedResponse.data
            return cachedResponse.data
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let cachedResponse = CachedURLResponse(response: response, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: request)
        memoryCache[url] = data
        return data
    }
}
