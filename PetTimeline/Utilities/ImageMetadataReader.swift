import Foundation
import ImageIO

/// 单张图片解析出的元数据
struct PhotoMetadata {
    var captureDate: Date?
    var latitude: Double?
    var longitude: Double?
}

/// 基于 ImageIO 的轻量元数据解析器。
/// 使用 `CGImageSourceCreateWithData` + `CGImageSourceCopyPropertiesAtIndex`，
/// 只读取元数据，不解码像素，避免内存与耗时开销。
enum ImageMetadataReader {
    
    /// 从图片 Data 解析 EXIF 拍摄时间与 GPS 经纬度
    static func read(from data: Data) -> PhotoMetadata {
        var metadata = PhotoMetadata()
        
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return metadata
        }
        
        metadata.captureDate = parseCaptureDate(from: properties)
        let coordinate = parseCoordinate(from: properties)
        metadata.latitude = coordinate?.latitude
        metadata.longitude = coordinate?.longitude
        
        return metadata
    }
    
    // MARK: - 拍摄时间
    
    private static func parseCaptureDate(from properties: [CFString: Any]) -> Date? {
        // 优先 EXIF DateTimeOriginal
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
           let date = exifDateFormatter.date(from: original) {
            return date
        }
        
        // 其次 EXIF DateTimeDigitized
        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let digitized = exif[kCGImagePropertyExifDateTimeDigitized] as? String,
           let date = exifDateFormatter.date(from: digitized) {
            return date
        }
        
        // 再其次 TIFF DateTime
        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let tiffDate = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = exifDateFormatter.date(from: tiffDate) {
            return date
        }
        
        return nil
    }
    
    /// EXIF 时间字符串格式为 "yyyy:MM:dd HH:mm:ss"
    private static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()
    
    // MARK: - GPS
    
    private static func parseCoordinate(from properties: [CFString: Any]) -> (latitude: Double, longitude: Double)? {
        guard let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] else {
            return nil
        }
        
        guard let rawLatitude = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
              let rawLongitude = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue else {
            return nil
        }
        
        // N/S、E/W 决定正负；缺失 Ref 时按正值处理
        let latitudeRef = (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased()
        let longitudeRef = (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased()
        
        let latitude = latitudeRef == "S" ? -abs(rawLatitude) : abs(rawLatitude)
        let longitude = longitudeRef == "W" ? -abs(rawLongitude) : abs(rawLongitude)
        
        // 过滤无效的 (0,0) 坐标，避免出现无意义的定位
        if latitude == 0 && longitude == 0 { return nil }
        
        return (latitude, longitude)
    }
}
