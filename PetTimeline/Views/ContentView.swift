import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        PetTimelineView()
    }
}

// MARK: - Xcode Previews
#Preview {
    let container = try! ModelContainer(
        for: Pet.self, TimelineEvent.self, EventPhoto.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext
    
    // 注入示例宠物
    let pet = Pet(name: "豆豆", species: "猫", birthDate: Calendar.current.date(byAdding: .year, value: -2, to: Date()))
    context.insert(pet)
    
    // 注入示例事件
    let calendar = Calendar.current
    let today = Date()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
    let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
    let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
    
    let events = [
        TimelineEvent(date: today, title: "今天的新玩具", content: "买了个羽毛逗猫棒，豆豆玩疯了", eventType: .daily, pet: pet),
        TimelineEvent(date: yesterday, title: "疫苗加强针", content: "三联疫苗第二针，打完有点困", eventType: .medical, locationName: "幸福动物医院", pet: pet),
        TimelineEvent(date: threeDaysAgo, title: "满两岁啦！", content: "豆豆生日快乐 🎂 吃了罐头庆祝", eventType: .milestone, pet: pet),
        TimelineEvent(date: weekAgo, title: "剪指甲", content: "抓挠板磨不下来，不得不剪", eventType: .daily, pet: pet),
    ]
    events.forEach { context.insert($0) }
    try? context.save()
    
    return ContentView()
        .modelContainer(container)
}
