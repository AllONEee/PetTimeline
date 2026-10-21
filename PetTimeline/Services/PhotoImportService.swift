import Foundation
import SwiftUI
import Photos
import PhotosUI
import SwiftData
import ImageIO
import CoreLocation

/// 照片批量导入服务
///
/// 设计要点：
/// - 入口为 PhotosPicker 多选（`selectionBehavior: .ordered`）
/// - 每张照片提取元数据：拍摄时间（EXIF DateTimeOriginal → PHAsset.creationDate → 当前时间）、GPS 经纬度
/// - 按“拍摄日期（精确到天）”分组
/// - 每个日期分组：该日期已有事件则追加照片，否则自动创建 TimelineEvent（daily / "照片回忆" / 空内容）
/// - 处理 iCloud 照片下载，提供异步加载进度提示
/// - 单例，主方法 `importPhotos(_:into:selectedPet:progress:) async throws`
///
/// 已知风险：PhotosPicker 返回的 Data 可能已被转码，导致 GPS 字段丢失。
/// 因此当 GPS 读取失败或 imageData 为空时，回退到 `PHAsset.fetchAssets(withLocalIdentifiers:)`
/// 配合 `PHAssetResourceManager` 获取原始文件数据再解析。
@MainActor
final class PhotoImportService {

    static let shared = PhotoImportService()
    private init() {}

    /// 进度回调：(完成比例 0~1, 状态文案)
    typealias ProgressHandler = @MainActor (Double, String) -> Void

    /// 批量导入照片到 SwiftData
    func importPhotos(
        _ items: [PhotosPickerItem],
        into context: ModelContext,
        selectedPet: Pet?,
        progress: ProgressHandler? = nil
    ) async throws {
        guard !items.isEmpty else { return }

        let total = items.count
        var results: [ImportedPhoto] = []
        results.reserveCapacity(total)

        // 1. 逐张加载数据并解析元数据
        for (index, item) in items.enumerated() {
            progress?(Double(index) / Double(total), "正在读取第 \(index + 1)/\(total) 张照片…")

            let imported = try await loadPhoto(from: item)
            results.append(imported)
        }

        progress?(0.55, "正在按日期分组…")

        // 2. 按拍摄日期（精确到天）分组
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: results) { photo -> String in
            let day = calendar.startOfDay(for: photo.captureDate ?? Date())
            return DateFormatter.dateOnly.string(from: day)
        }

        // 3. 预先取出可能命中的已有事件，建立“日期 -> 事件”映射
        let dayKeys = grouped.keys.compactMap { DateFormatter.dateOnly.date(from: $0) }
        var existingByDay: [String: TimelineEvent] = [:]
        if let earliest = dayKeys.min(), let latest = dayKeys.max() {
            let upperBound = calendar.date(byAdding: .day, value: 1, to: latest) ?? latest
            let descriptor = FetchDescriptor<TimelineEvent>(
                predicate: #Predicate { event in
                    event.date >= earliest && event.date < upperBound
                }
            )
            for event in try context.fetch(descriptor) {
                let key = DateFormatter.dateOnly.string(from: calendar.startOfDay(for: event.date))
                existingByDay[key] = event
            }
        }

        // 4. 逐日期处理：追加到已有事件或新建事件
        let sortedKeys = grouped.keys.sorted(by: >)
        for (keyIndex, key) in sortedKeys.enumerated() {
            guard let photos = grouped[key] else { continue }

            let fraction = 0.55 + 0.4 * (Double(keyIndex) / Double(max(sortedKeys.count, 1)))
            progress?(fraction, "正在归档 \(key) 的照片…")

            let event: TimelineEvent
            if let existing = existingByDay[key] {
                event = existing
            } else {
                let day = DateFormatter.dateOnly.date(from: key) ?? Date()
                let newEvent = TimelineEvent(
                    date: day,
                    title: "照片回忆",
                    content: "",
                    eventType: .daily,
                    pet: selectedPet
                )
                context.insert(newEvent)
                existingByDay[key] = newEvent
                event = newEvent
            }

            for photo in photos {
                let entity = EventPhoto(
                    imageData: photo.imageData,
                    captureDate: photo.captureDate,
                    latitude: photo.latitude,
                    longitude: photo.longitude,
                    event: event
                )
                context.insert(entity)
                event.photos.append(entity)
            }

            // 事件本身也补上照片地点（若事件无地点且照片有 GPS）
            if event.locationName == nil,
               let withLocation = photos.first(where: { $0.latitude != nil && $0.longitude != nil }) {
                // 异步反向地理编码
                if let lat = withLocation.latitude, let lon = withLocation.longitude {
                    let locationName = await reverseGeocode(latitude: lat, longitude: lon)
                    event.locationName = locationName
                }
            }
        }

        progress?(0.95, "正在保存…")
        try context.save()
        progress?(1.0, "导入完成")
    }

    // MARK: - 单张照片加载

    private struct ImportedPhoto {
        var imageData: Data
        var captureDate: Date?
        var latitude: Double?
        var longitude: Double?
    }

    private func loadPhoto(from item: PhotosPickerItem) async throws -> ImportedPhoto {
        // 先走 PhotosPicker 的转码数据
        var imageData = try await item.loadTransferable(type: Data.self) ?? Data()
        var metadata = ImageMetadataReader.read(from: imageData)

        // 通过 itemIdentifier 找回原始相册资源
        if let localIdentifier = item.itemIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
            let asset = fetchResult.firstObject

            // 拍摄时间兜底：EXIF 缺失时用相册创建时间
            if metadata.captureDate == nil, let creationDate = asset?.creationDate {
                metadata.captureDate = creationDate
            }

            // 修复：如果 imageData 为空（loadTransferable 失败），或者 GPS 缺失，
            // 都要尝试取原始文件重新解析（PhotosPicker 可能已剥离 GPS 或转码失败）
            let needsOriginalFile = imageData.isEmpty || metadata.latitude == nil || metadata.longitude == nil || metadata.captureDate == nil
            if needsOriginalFile, let asset = asset, let originalData = await originalFileData(for: asset) {
                let originalMetadata = ImageMetadataReader.read(from: originalData)
                if metadata.latitude == nil { metadata.latitude = originalMetadata.latitude }
                if metadata.longitude == nil { metadata.longitude = originalMetadata.longitude }
                if metadata.captureDate == nil { metadata.captureDate = originalMetadata.captureDate }

                // 若转码数据为空，直接使用原始数据
                if imageData.isEmpty {
                    imageData = originalData
                }
            }
        }

        // 最终兜底
        if metadata.captureDate == nil {
            metadata.captureDate = Date()
        }

        return ImportedPhoto(
            imageData: imageData,
            captureDate: metadata.captureDate,
            latitude: metadata.latitude,
            longitude: metadata.longitude
        )
    }

    /// 读取相册资源的原始文件数据，允许触发 iCloud 下载
    private func originalFileData(for asset: PHAsset) async -> Data? {
        let resources = PHAssetResource.assetResources(for: asset)
        guard let resource = resources.first(where: { $0.type == .photo }) ?? resources.first else {
            return nil
        }

        let options = PHAssetResourceRequestOptions()
        options.isNetworkAccessAllowed = true

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("pet-timeline-import-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = PHAssetResourceManager.default()
        return await withCheckedContinuation { continuation in
            manager.writeData(for: resource, toFile: fileURL, options: options) { error in
                guard error == nil else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: try? Data(contentsOf: fileURL))
            }
        }
    }

    /// 反向地理编码：经纬度转为 "XX省·XX市" 格式
    private func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                var components: [String] = []
                if let province = placemark.administrativeArea { components.append(province) }
                if let city = placemark.locality { components.append(city) }
                if !components.isEmpty {
                    return components.joined(separator: "·")
                }
            }
        } catch {
            print("反向地理编码失败: \(error)")
        }
        return nil
    }
}
