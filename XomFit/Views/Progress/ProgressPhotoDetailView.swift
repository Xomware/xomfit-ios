import SwiftUI

struct ProgressPhotoDetailView: View {
    let photos: [ProgressPhoto]
    let initialPhoto: ProgressPhoto
    let photoService: ProgressPhotoService
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                    ZStack(alignment: .bottom) {
                        if let image = photoService.loadImage(for: photo) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // Annotation overlay
                        VStack(spacing: 4) {
                            Text(photo.date.formatted(date: .long, time: .omitted))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            if let weight = photo.weightKg {
                                Text(String(format: "%.1f kg", weight))
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            
                            if let notes = photo.notes, !notes.isEmpty {
                                Text(notes)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(.black.opacity(0.5))
                        .cornerRadius(12)
                        .padding(.bottom, 40)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            currentIndex = photos.firstIndex(where: { $0.id == initialPhoto.id }) ?? 0
        }
    }
}
