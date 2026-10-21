import SwiftUI
import SwiftData
import PhotosUI

/// 宠物档案管理页：新建、编辑、删除宠物
struct PetManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Pet.name) private var pets: [Pet]
    
    @State private var showAddPet = false
    @State private var editingPet: Pet?
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(pets) { pet in
                    HStack(spacing: 12) {
                        // 头像
                        ZStack {
                            if let avatarData = pet.avatarData,
                               let uiImage = UIImage(data: avatarData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "pawprint.circle.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(.orange)
                                    .frame(width: 56, height: 56)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(pet.name.isEmpty ? "无名宠物" : pet.name)
                                .font(.headline)
                            Text(pet.species.isEmpty ? "未设置物种" : pet.species)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let birthDate = pet.birthDate {
                                HStack {
                                    Text("生日：")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(birthDate, format: .dateTime.year().month().day())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            editingPet = pet
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
                .onDelete(perform: deletePets)
            }
            .navigationTitle("宠物管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddPet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddPet) {
                AddEditPetView()
            }
            .sheet(item: $editingPet) { pet in
                AddEditPetView(pet: pet)
            }
        }
    }
    
    private func deletePets(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(pets[index])
        }
        try? modelContext.save()
    }
}

/// 添加/编辑宠物表单
struct AddEditPetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let pet: Pet?
    
    @State private var name: String = ""
    @State private var species: String = ""
    @State private var birthDate: Date = Date()
    @State private var avatarImage: UIImage?
    
    @State private var showPhotoPicker = false
    @State private var photoPickerItem: PhotosPickerItem?
    
    private var isEditing: Bool { pet != nil }
    
    init(pet: Pet? = nil) {
        self.pet = pet
        _name = State(initialValue: pet?.name ?? "")
        _species = State(initialValue: pet?.species ?? "")
        _birthDate = State(initialValue: pet?.birthDate ?? Date())
        if let data = pet?.avatarData {
            _avatarImage = State(initialValue: UIImage(data: data))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("头像") {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            if let image = avatarImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 100, height: 100)
                            }
                            Button("更换头像") {
                                showPhotoPicker = true
                            }
                            .font(.caption)
                        }
                        Spacer()
                    }
                    .photosPicker(isPresented: $showPhotoPicker, selection: $photoPickerItem, matching: .images)
                    .onChange(of: photoPickerItem) { _, newItem in
                        Task {
                            if let item = newItem,
                               let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                avatarImage = image
                            }
                            photoPickerItem = nil
                        }
                    }
                }
                
                Section("基本信息") {
                    TextField("宠物名字", text: $name)
                    TextField("物种（如：猫、狗、兔子）", text: $species)
                    DatePicker("出生日期", selection: $birthDate, displayedComponents: .date)
                }
            }
            .navigationTitle(isEditing ? "编辑宠物" : "添加宠物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        savePet()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func savePet() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSpecies = species.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let existing = pet {
            existing.name = trimmedName
            existing.species = trimmedSpecies
            existing.birthDate = birthDate
            if let avatarImage = avatarImage,
               let data = avatarImage.jpegData(compressionQuality: 0.8) {
                existing.avatarData = data
            }
        } else {
            let newPet = Pet(
                id: UUID(),
                name: trimmedName,
                species: trimmedSpecies,
                avatarData: avatarImage?.jpegData(compressionQuality: 0.8),
                birthDate: birthDate
            )
            modelContext.insert(newPet)
        }
        
        try? modelContext.save()
        dismiss()
    }
}
