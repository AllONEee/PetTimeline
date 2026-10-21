import Foundation
import SwiftData

@Model
final class TimelineEvent {
    @Attribute(.unique) var id: UUID
    var date: Date
    var title: String
    var content: String
    var eventType: EventType
    var locationName: String?
    
    /// 事件所属宠物。删除事件不应删除宠物，因此使用 nullify。
    @Relationship(deleteRule: .nullify) var pet: Pet?
    
    /// 事件下的照片，删除事件时级联删除。
    @Relationship(deleteRule: .cascade, inverse: \EventPhoto.event) var photos: [EventPhoto] = []
    
    init(id: UUID = UUID(),
         date: Date = Date(),
         title: String = "",
         content: String = "",
         eventType: EventType = .daily,
         locationName: String? = nil,
         pet: Pet? = nil,
         photos: [EventPhoto] = []) {
        self.id = id
        self.date = date
        self.title = title
        self.content = content
        self.eventType = eventType
        self.locationName = locationName
        self.pet = pet
        self.photos = photos
    }
}
