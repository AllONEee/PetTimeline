import Foundation
import SwiftUI

/// 事件类型：日常 / 医院 / 里程碑 / 其他
enum EventType: String, Codable, CaseIterable, Identifiable {
    case daily
    case medical
    case milestone
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "日常"
        case .medical: return "医院"
        case .milestone: return "里程碑"
        case .other: return "其他"
        }
    }

    var iconName: String {
        switch self {
        case .daily: return "pawprint.fill"
        case .medical: return "cross.case.fill"
        case .milestone: return "star.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// 事件类型对应颜色，集中管理便于统一调整视觉规范
    var color: Color {
        switch self {
        case .daily: return .orange
        case .medical: return .red
        case .milestone: return .yellow
        case .other: return .blue
        }
    }
}
