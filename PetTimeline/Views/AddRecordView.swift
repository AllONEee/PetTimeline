import SwiftUI
import SwiftData

/// 为已有事件补充文字描述（多用于批量导入照片后，给当天补一条记录）
struct AddRecordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let event: TimelineEvent

    @State private var date: Date
    @State private var eventType: EventType
    @State private var title: String
    @State private var content: String
    @State private var locationName: String

    init(event: TimelineEvent) {
        self.event = event
        _date = State(initialValue: event.date)
        _eventType = State(initialValue: event.eventType)
        _title = State(initialValue: event.title)
        _content = State(initialValue: event.content)
        _locationName = State(initialValue: event.locationName ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("日期") {
                    DatePicker("发生时间", selection: $date)
                        .datePickerStyle(.automatic)
                }

                Section("类型") {
                    Picker("事件类型", selection: $eventType) {
                        ForEach(EventType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("标题") {
                    TextField("例如：第一次洗澡", text: $title)
                }

                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                }

                Section("地点") {
                    TextField("例如：小区楼下宠物店", text: $locationName)
                }
            }
            .navigationTitle("编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        event.date = date
        event.eventType = eventType
        event.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.content = content
        event.locationName = locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? nil
            : locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        try? modelContext.save()
        dismiss()
    }
}
