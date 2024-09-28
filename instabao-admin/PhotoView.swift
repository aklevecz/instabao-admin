//
//  PhotoView.swift
//  instabao-admin
//
//  Created by Ariel Klevecz on 9/27/24.
//

/*
See the License.txt file for this sample’s licensing information.
*/

import SwiftUI
import Photos

struct PhotoView: View {
    var asset: PhotoAsset
    
    var cache: CachedImageManager?
    @State private var image: Image?
    @State private var imageRequestID: PHImageRequestID?
    @State private var isUploading: Bool = false
    @State private var isUploaded: Bool = false
    @State private var showUploadSuccessAlert: Bool = false

    @State private var uploadError: Bool = false
    @State private var descriptionText = ""
    
    @Environment(\.dismiss) var dismiss
    private let imageSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        ZStack {
//            Color.secondary.ignoresSafeArea()
            
            VStack {
                if let image = image {
                    image
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(asset.accessibilityLabel)
                } else {
                    ProgressView()
                }
                
                TextField("Enter description", text: $descriptionText)
                    .padding()
                    .cornerRadius(8)
                    .padding(.horizontal)
                
                buttonsView()
                    .padding(.bottom, 50)
            }
            
            if isUploading {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(2)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
        }
        .navigationTitle("Photo")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard image == nil, let cache = cache else { return }
            imageRequestID = await cache.requestImage(for: asset, targetSize: imageSize) { result in
                Task {
                    if let result = result {
                        self.image = result.image
                    }
                }
            }
        }
        .alert("Upload Failed", isPresented: $uploadError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("There was an error uploading the asset. Please try again.")
        }
        .alert("Upload Successful", isPresented: $showUploadSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The asset has been successfully uploaded.")
        }
        .onAppear {
            isUploaded = UploadedPhotosService.shared.uploadedPhotos.contains(asset.id)
        }
    }
    
    private func buttonsView() -> some View {
        HStack(spacing: 60) {
            Button {
                Task {
                    await asset.setIsFavorite(!asset.isFavorite)
                }
            } label: {
                Label("Favorite", systemImage: asset.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 24))
            }
            .disabled(isUploading)
            
            Button {
                Task { @MainActor in  // Add @MainActor here
                    isUploading = true
                    let success = await asset.upload(description: descriptionText)
                    isUploading = false
                    if success {
                        isUploaded = true
                        showUploadSuccessAlert = true
                        await UploadedPhotosService.shared.fetchUploadedPhotos()
                    } else {
                        uploadError = true
                    }
                }
            } label: {
                Label("Upload", systemImage: isUploaded ? "checkmark.circle" : "paperplane")
                    .font(.system(size: 24))
            }
            .disabled(isUploading || isUploaded)
            
            Button {
                Task {
                    await asset.delete()
                    await MainActor.run {
                        dismiss()
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 24))
            }
            .disabled(isUploading)
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30))
        .cornerRadius(15)
    }
}
