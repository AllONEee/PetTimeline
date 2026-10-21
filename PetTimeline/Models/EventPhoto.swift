import Foundation
import SwiftData
import CoreLocation

@Model
final class EventPhoto {
    @Attribute(.unique) var id: UUID
    var imageData: Data
    var captureDate: Date?
    var latitude: Double?
    var longitude: Double?
    
    /// inverse 由 TimelineEvent.photos 一侧声明，这里只保留删除规则，避免双向 inverse 造成循环引用
    var event: TimelineEvent?
    
    init(id: UUID = UUID(),
         imageData: Data,
         captureDate: Date? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         event: TimelineEvent? = nil) {
        self.id = id
        self.imageData = imageData
        self.captureDate = captureDate
        self.latitude = latitude
        self.longitude = longitude
        self.event = event
    }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
