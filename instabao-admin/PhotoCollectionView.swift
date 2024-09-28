//
//  PhotoCollectionView.swift
//  instabao-admin
//
//  Created by Ariel Klevecz on 9/27/24.
//
import SwiftUI

struct PhotoCollectionView: View {
    @ObservedObject var photoCollection : PhotoCollection
    @State private var showAlert = false

    @Environment(\.displayScale) private var displayScale
        
    private static let itemSpacing = 12.0
    private static let itemCornerRadius = 15.0
    private static let itemSize = CGSize(width: 90, height: 90)
    
    private var imageSize: CGSize {
        return CGSize(width: Self.itemSize.width * min(displayScale, 2), height: Self.itemSize.height * min(displayScale, 2))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: itemSize.width, maximum: itemSize.height), spacing: itemSpacing)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Self.itemSpacing) {
                ForEach(photoCollection.photoAssets) { asset in
                    NavigationLink {
                        PhotoView(asset: asset, cache: photoCollection.cache)
                    } label: {
                        photoItemView(asset: asset)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(asset.accessibilityLabel)
                    .onTapGesture {
                        print("Tapped on photo asset: \(asset)")
                    }
                }
            }
            .padding([.vertical], Self.itemSpacing)
        }
        .navigationTitle(photoCollection.albumName ?? "Gallery")
        .navigationBarTitleDisplayMode(.inline)
        .statusBar(hidden: false)
        .onAppear {
            Task {
                await UploadedPhotosService.shared.fetchUploadedPhotos()
//                                showAlert = true
            }
        }
                .alert(isPresented: $showAlert) {
            Alert(title: Text("Photos Fetched"), message: Text("The photos have been fetched from the server."), dismissButton: .default(Text("OK")))
        }
        
    }
    
    private func photoItemView(asset: PhotoAsset) -> some View {
        PhotoItemView(asset: asset, cache: photoCollection.cache, imageSize: imageSize)
            .frame(width: Self.itemSize.width, height: Self.itemSize.height)
            .clipped()
            .cornerRadius(Self.itemCornerRadius)
            .overlay(alignment: .bottomLeading) {
                if asset.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 1)
                        .font(.callout)
                        .offset(x: 4, y: -4)
                }
            }
            .onAppear {
                Task {
                    await photoCollection.cache.startCaching(for: [asset], targetSize: imageSize)
                }
            }
            .onDisappear {
                Task {
                    await photoCollection.cache.stopCaching(for: [asset], targetSize: imageSize)
                }
            }
    }
}

struct PhotoCollectionView_Previews: PreviewProvider {
    static var model = DataModel()
    static var previews: some View {
        PhotoCollectionView(photoCollection: model.photoCollection)
    }
}
