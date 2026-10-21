import SwiftUI
import SwiftData
import PhotosUI
import CoreLocation

/// 手动添加事件表单
struct AddEventView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// 当前选中的宠物（用于多宠物切换）
    @Binding var selectedPet: Pet?

    @State private var date: Date = Date()
    @State private var eventType: EventType = .daily
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var locationName: String = ""
    @State private var photoItems: [PhotosPickerItem] = []

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
                        .frame(minHeight: 120)
                }

                Section("地点") {
                    TextField("例如：小区楼下宠物店", text: $locationName)
                }

                Section("照片") {
                    PhotosPicker(
                        selection: $photoItems,
                        maxSelectionCount: 1,
                        selectionBehavior: .ordered,
                        matching: .images
                    ) {
                        Label("从相册添加一张照片", systemImage: "photo.badge.plus")
                    }
                }
            }
            .navigationTitle("添加事件")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() async {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)

        let event = TimelineEvent(
            date: date,
            title: trimmedTitle,
            content: content,
            eventType: eventType,
            locationName: trimmedLocation.isEmpty ? nil : trimmedLocation,
            pet: selectedPet
        )
        modelContext.insert(event)

        // 单张照片：直接解析元数据
        if let item = photoItems.first {
            if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                let metadata = ImageMetadataReader.read(from: data)

                // 若有 GPS，异步反向地理编码为 "XX省·XX市"
                var finalLocation = trimmedLocation.isEmpty ? nil : trimmedLocation
                if finalLocation == nil, let lat = metadata.latitude, let lon = metadata.longitude {
                    finalLocation = await reverseGeocode(latitude: lat, longitude: lon)
                }

                let photo = EventPhoto(
                    imageData: data,
                    captureDate: metadata.captureDate,
                    latitude: metadata.latitude,
                    longitude: metadata.longitude,
                    event: event
                )
                modelContext.insert(photo)
                event.photos.append(photo)

                // 若事件尚无地点且照片有 GPS，补上地点
                if event.locationName == nil, finalLocation != nil {
                    event.locationName = finalLocation
                }
            }
        }

        try? modelContext.save()
        dismiss()
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
