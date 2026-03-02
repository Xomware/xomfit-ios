import SwiftUI
import PhotosUI

struct ProgressPhotoView: View {
    @StateObject private var photoService = ProgressPhotoService.shared
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedPhoto: ProgressPhoto?
    @State private var showDetail = false
    
    private let columns = [
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4),
        GridItem(.flexible(), spacing: 4)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progress Photos")
                    .font(Theme.fontHeadline)
                    .foregroundStyle(Theme.textPrimary)
                
                Spacer()
                
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                }
            }
            
            if photoService.photos.isEmpty {
                Text("No progress photos yet. Tap + to add your first.")
                    .font(Theme.fontCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.paddingLarge)
            } else {
                LazyVGrid(columns: columns, spacing: 4) {
                    ForEach(photoService.photos) { photo in
                        Button {
                            selectedPhoto = photo
                            showDetail = true
                        } label: {
                            ProgressPhotoThumbnail(photo: photo, photoService: photoService)
                        }
                    }
                }
            }
        }
        .cardStyle()
        .onChange(of: selectedItem) { _, newItem in
            Task {
                guard let newItem,
                      let data = try? await newItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                _ = photoService.addPhoto(image: image, date: Date())
                selectedItem = nil
            }
        }
        .fullScreenCover(isPresented: $showDetail) {
            if let photo = selectedPhoto {
                ProgressPhotoDetailView(
                    photos: photoService.photos,
                    initialPhoto: photo,
                    photoService: photoService
                )
            }
        }
    }
}

private struct ProgressPhotoThumbnail: View {
    let photo: ProgressPhoto
    let photoService: ProgressPhotoService
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = photoService.loadImage(for: photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Theme.secondaryBackground)
                    .aspectRatio(1, contentMode: .fill)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(Theme.textSecondary)
                    }
            }
            
            Text(photo.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(4)
                .background(.black.opacity(0.6))
                .cornerRadius(4)
                .padding(4)
        }
        .cornerRadius(Theme.cornerRadiusSmall)
    }
}
