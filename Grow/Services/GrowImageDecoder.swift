import CryptoKit
import Foundation
import ImageIO
import UIKit

enum GrowImageDecodingError: Error, Equatable {
    case invalidData
    case invalidMaxPixelSize
}

private final class CGImageBox: @unchecked Sendable {
    let image: CGImage

    nonisolated init(_ image: CGImage) {
        self.image = image
    }
}

private final class CGImageCache: @unchecked Sendable {
    nonisolated(unsafe) private let storage = NSCache<NSString, CGImageBox>()
    nonisolated private let lock = NSLock()
    nonisolated(unsafe) private var costs: [String: Int] = [:]
    nonisolated(unsafe) private var currentCost = 0
    nonisolated let totalCostLimit: Int

    nonisolated init(totalCostLimit: Int) {
        self.totalCostLimit = totalCostLimit
        storage.totalCostLimit = totalCostLimit
    }

    nonisolated func object(forKey key: NSString) -> CGImageBox? {
        storage.object(forKey: key)
    }

    nonisolated func setObject(_ object: CGImageBox, forKey key: NSString, cost: Int) {
        guard cost <= totalCostLimit else { return }
        lock.lock()
        defer { lock.unlock() }

        let stringKey = key as String
        if let previousCost = costs[stringKey] {
            currentCost -= previousCost
        }
        if currentCost + cost > totalCostLimit {
            storage.removeAllObjects()
            costs.removeAll()
            currentCost = 0
        }
        storage.setObject(object, forKey: key, cost: cost)
        costs[stringKey] = cost
        currentCost += cost
    }

    nonisolated func removeAllObjects() {
        lock.lock()
        defer { lock.unlock() }
        storage.removeAllObjects()
        costs.removeAll()
        currentCost = 0
    }

    nonisolated var estimatedCost: Int {
        lock.lock()
        defer { lock.unlock() }
        return currentCost
    }
}

actor GrowImageDecoder {
    static let cacheCostLimit = 64 * 1_024 * 1_024

    private let cache = CGImageCache(totalCostLimit: cacheCostLimit)
    private let notificationCenter: NotificationCenter
    private var memoryWarningObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        memoryWarningObserver = notificationCenter.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: nil
        ) { [cache] _ in
            cache.removeAllObjects()
        }
    }

    deinit {
        if let memoryWarningObserver {
            notificationCenter.removeObserver(memoryWarningObserver)
        }
    }

    func image(
        data: Data,
        maxPixelSize: Int,
        sourceID: String? = nil
    ) throws -> CGImage {
        try Task.checkCancellation()
        guard maxPixelSize > 0 else {
            throw GrowImageDecodingError.invalidMaxPixelSize
        }

        let cacheKey = cacheKey(
            data: data,
            sourceID: sourceID,
            maxPixelBucket: maxPixelSize
        )
        if let cached = cache.object(forKey: cacheKey) {
            try Task.checkCancellation()
            return cached.image
        }

        try Task.checkCancellation()
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw GrowImageDecodingError.invalidData
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        try Task.checkCancellation()
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw GrowImageDecodingError.invalidData
        }

        try Task.checkCancellation()
        let cost = image.bytesPerRow * image.height
        cache.setObject(CGImageBox(image), forKey: cacheKey, cost: cost)
        return image
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    var estimatedCacheCost: Int {
        cache.estimatedCost
    }

    private func cacheKey(
        data: Data,
        sourceID: String?,
        maxPixelBucket: Int
    ) -> NSString {
        let identity: String
        if let sourceID, !sourceID.isEmpty {
            identity = sourceID
        } else {
            identity = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        return "\(identity):\(maxPixelBucket)" as NSString
    }
}
