import Foundation
import SwiftData

@Model
final class Pet {
    @Attribute(.unique) var id: UUID
    var name: String
    var species: String
    var avatarData: Data?
    var birthDate: Date?

    init(id: UUID = UUID(), name: String = "", species: String = "", avatarData: Data? = nil, birthDate: Date? = nil) {
        self.id = id
        self.name = name
        self.species = species
        self.avatarData = avatarData
        self.birthDate = birthDate
    }
}
