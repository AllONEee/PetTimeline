import SwiftUI
import SwiftData
import PhotosUI

/// 当日详情页：集成编辑/增删照片、编辑/删除记录、删除整日
struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var event: TimelineEvent

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showPhotoEditor = false
    @State private var editorPhotoIndex = 0
    @State private var showDeleteEventConfirm = false
    @State private var showAddRecord = false
    @State private var showEditRecord = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: 照片区
                Section {
                    if event.photos.isEmpty {
                        PhotosPicker(
                            selection: $photoItems,
                            maxSelectionCount: 9,
                            matching: .images
                        ) {
                            Label("添加照片", systemImage: "photo.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(event.photos.enumerated()), id: \.element.id) { idx, photo in
                                    ZStack(alignment: .topTrailing) {
                                        if let ui = UIImage(data: photo.imageData) {
                                            Image(uiImage: ui)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        Button(role: .destructive) {
                                            withAnimation {
                                                event.photos.remove(at: idx)
                                                try? modelContext.save()
                                            }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.title2)
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .red)
                                                .offset(x: 8, y: -8)
                                        }
                                    }
                                    .onTapGesture {
                                        editorPhotoIndex = idx
                                        showPhotoEditor = true
                                    }
                                }
                                // 添加更多照片
                                if event.photos.count < 9 {
                                    PhotosPicker(
                                        selection: $photoItems,
                                        maxSelectionCount: 9 - event.photos.count,
                                        matching: .images
                                    ) {
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Image(systemName: "plus")
                                                    .font(.title)
                                                    .foregroundStyle(.secondary)
                                            )
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: { Text("照片") }

                // MARK: 记录区
                Section {
                    let hasContent = !event.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    if !hasContent {
                        Button { showAddRecord = true } label: {
                            Label("添加记录", systemImage: "square.and.pencil")
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            if !event.title.isEmpty {
                                Text(event.title).font(.headline)
                            }
                            Text(event.content)
                                .font(.body)
                                .foregroundStyle(.secondary)
                            if let loc = event.locationName {
                                Label(loc, systemImage: "location")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .contextMenu {
                            Button("编辑", systemImage: "pencil") { showEditRecord = true }
                            Button("删除", systemImage: "trash", role: .destructive) {
                                event.title = ""
                                event.content = ""
                                event.locationName = nil
                                try? modelContext.save()
                            }
                        }
                        .onTapGesture { showEditRecord = true }
                    }
                } header: { Text("记录") }

                // MARK: 危险区
                Section {
                    Button(role: .destructive) { showDeleteEventConfirm = true } label: {
                        Label("删除当日所有内容", systemImage: "trash")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("当日详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: photoItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self), !data.isEmpty {
                            let meta = ImageMetadataReader.read(from: data)
                            let ph = EventPhoto(
                                imageData: data,
                                captureDate: meta.captureDate,
                                latitude: meta.latitude,
                                longitude: meta.longitude,
                                event: event
                            )
                            modelContext.insert(ph)
                            event.photos.append(ph)
                        }
                    }
                    try? modelContext.save()
                    photoItems = []
                }
            }
            .fullScreenCover(isPresented: $showPhotoEditor) {
                PhotoEditorView(imageData: event.photos[editorPhotoIndex].imageData) { newData in
                    event.photos[editorPhotoIndex].imageData = newData
                    try? modelContext.save()
                }
            }
            .sheet(isPresented: $showAddRecord) { AddRecordView(event: event) }
            .sheet(isPresented: $showEditRecord) { AddRecordView(event: event) }
            .alert("删除当日所有内容？", isPresented: $showDeleteEventConfirm) {
                Button("删除", role: .destructive) {
                    modelContext.delete(event)
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}
