import Foundation

extension DateFormatter {
    /// 相对时间格式化器（今天、昨天、前天等）
    static let relative: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .short
        f.timeStyle = .none
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()
    
    /// 完整日期时间格式（用于展开详情）
    static let fullDateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        f.timeStyle = .short
        f.locale = Locale(identifier: "zh_CN")
        return f
    }()
    
    /// 仅日期（用于分组键：yyyy-MM-dd）
    static let dateOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "zh_CN")
        f.timeZone = TimeZone.current
        return f
    }()
}

extension Date {
    /// 返回相对时间字符串（如 "今天"、"昨天"、"前天"；更久远则返回年月日）
    var displayDateString: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) { return "今天" }
        if calendar.isDateInYesterday(self) { return "昨天" }
        // 前天
        let dayBeforeYesterday = calendar.date(byAdding: .day, value: -2, to: now)!
        if calendar.isDate(self, equalTo: dayBeforeYesterday, toGranularity: .day) { return "前天" }
        
        // 否则返回年月日格式
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月dd日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
    
    /// 返回完整日期时间字符串
    var fullDateTimeString: String {
        DateFormatter.fullDateTime.string(from: self)
    }
    
    /// 返回仅日期字符串（用于分组键）
    var dateOnlyString: String {
        DateFormatter.dateOnly.string(from: self)
    }
    
    /// 当天开始时间
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// 当天结束时间
    var endOfDay: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!.addingTimeInterval(-1)
    }
}
