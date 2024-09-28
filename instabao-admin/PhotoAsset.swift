//
//  PhotoAsset.swift
//  instabao-admin
//
//  Created by Ariel Klevecz on 9/27/24.
//

import Photos
import SwiftUI

struct PhotoAsset: Identifiable {
    var id: String { identifier }
    var identifier: String = UUID().uuidString
    var index: Int?
    var phAsset: PHAsset?
    @State public var isUploaded: Bool = false

    
    typealias MediaType = PHAssetMediaType
    
    var isFavorite: Bool {
        phAsset?.isFavorite ?? false
    }
    
    var mediaType: MediaType {
        phAsset?.mediaType ?? .unknown
    }
    
    var accessibilityLabel: String {
        "Photo\(isFavorite ? ", Favorite" : "")"
    }

    init(phAsset: PHAsset, index: Int?) {
        self.phAsset = phAsset
        self.index = index
        self.identifier = phAsset.localIdentifier
    }
    
    init(identifier: String) {
        self.identifier = identifier
        let fetchedAssets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        self.phAsset = fetchedAssets.firstObject
    }
    
    func setIsFavorite(_ isFavorite: Bool) async {
        guard let phAsset = phAsset else { return }
        Task {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetChangeRequest(for: phAsset)
                    request.isFavorite = isFavorite
                }
            } catch (let error) {
                print("Failed to change isFavorite: \(error.localizedDescription)")
            }
        }
    }

    func reverseGeocodeLocation(_ location: CLLocation) async throws -> (city: String, state: String) {
        let geocoder = CLGeocoder()
        let placemarks = try await geocoder.reverseGeocodeLocation(location)

        guard let placemark = placemarks.first else {
            throw NSError(domain: "NoPlacemarkError", code: 1, userInfo: nil)
        }

        let city = placemark.locality ?? ""
        let state = placemark.administrativeArea ?? ""

        return (city, state)
    }

    func exportVideoToMP4(avAsset: AVAsset) async throws -> Data {
        let exportSession = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality)!
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let outputURL = documentsPath.appendingPathComponent("output.mp4")
        
        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        await exportSession.export()
        
        guard exportSession.status == .completed else {
            throw NSError(domain: "VideoExportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to export video"])
        }
        
        let mp4Data = try Data(contentsOf: outputURL)
        
        // Clean up the temporary file
        try? FileManager.default.removeItem(at: outputURL)
        
        return mp4Data
    }
    
    func upload(description: String) async -> Bool  {
        guard let phAsset = self.phAsset else {
            print("No PHAsset found")
            return false
        }
        let isVideo = phAsset.mediaType == .video
        
        var latitude: CLLocationDegrees? = nil
        var longitude: CLLocationDegrees? = nil

        let creationDate = phAsset.creationDate
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ" // ISO 8601 format
        let creationDateString = dateFormatter.string(from: creationDate ?? Date())


        if let location = phAsset.location {
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
        }

        let location = CLLocation(latitude: latitude ?? 0, longitude: longitude ?? 0)
        return await withCheckedContinuation { continuation in
            if isVideo {
                PHImageManager.default().requestAVAsset(forVideo: phAsset, options: nil) { (avAsset, audioMix, info) in
                    Task {
                        do {
                            let (city, state) = try await reverseGeocodeLocation(location)
                            guard let urlAsset = avAsset as? AVURLAsset else {
                                print("Failed to get URL asset for video")
                                return
                            }
                            guard let avAsset = avAsset else {
                                print("Failed to get AVAsset for video")
                                return
                            }
                            let mp4Data = try await exportVideoToMP4(avAsset: avAsset)
                            let endpoint = "https://insta.baos.haus/instabao/images"
                            guard var urlComponents = URLComponents(string: endpoint) else {
                                print("Invalid URL")
                                return
                            }
                            print(self.id)
                            // Add id as a query parameter
                            urlComponents.queryItems = [
                                URLQueryItem(name: "id", value: self.id),
                                URLQueryItem(name:"description", value: description),
                                URLQueryItem(name: "latitude", value: String(latitude ?? 0)),
                                URLQueryItem(name: "longitude", value: String(longitude ?? 0)),
                                URLQueryItem(name:"creationDate", value: creationDateString),
                                URLQueryItem(name:"city", value: city),
                                URLQueryItem(name:"state", value: state),
                                URLQueryItem(name: "mediaType", value: isVideo ? "video" : "image")
                            ]
                            
                            guard let url = urlComponents.url else {
                                print("Invalid URL")
                                return
                            }
                            
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.httpBody = mp4Data
                            request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
                            print("uploading video")
                            let (_, response) = try await URLSession.shared.data(for: request)
                            
                            if let httpResponse = response as? HTTPURLResponse,
                               (200...299).contains(httpResponse.statusCode) {
                                self.isUploaded = true
                                print("Image upload successful")
                                continuation.resume(returning: true)
                            } else {
                                print("Server responded with unexpected status code")
                                continuation.resume(returning: false)
                            }
                        } catch {
                            print("Error uploading image: \(error)")
                            continuation.resume(returning: false)
                        }
                    }
                }
            } else {
                PHImageManager.default().requestImageDataAndOrientation(for: phAsset, options: nil) { (imageData, dataUTI, orientation, info) in
                    Task {
                        do {
                            let (city, state) = try await reverseGeocodeLocation(location)
                            
                            guard let imageData = imageData else {
                                print("No image data available")
                                return
                            }
                            guard let image = UIImage(data: imageData) else {
                                print("Invalid image data")
                                return
                            }
                            guard let jpegData = image.jpegData(compressionQuality: 1.0) else {
                                print("Failed to convert image to JPEG")
                                return
                            }
                            
                            let endpoint = "https://insta.baos.haus/instabao/images"
                            guard var urlComponents = URLComponents(string: endpoint) else {
                                print("Invalid URL")
                                return
                            }
                            
                            // Add id as a query parameter
                            urlComponents.queryItems = [
                                URLQueryItem(name: "id", value: self.id),
                                URLQueryItem(name:"description", value: description),
                                URLQueryItem(name: "latitude", value: String(latitude ?? 0)),
                                URLQueryItem(name: "longitude", value: String(longitude ?? 0)),
                                URLQueryItem(name:"creationDate", value: creationDateString),
                                URLQueryItem(name:"city", value: city),
                                URLQueryItem(name:"state", value: state),
                                URLQueryItem(name: "mediaType", value: isVideo ? "video" : "image")
                            ]
                            
                            guard let url = urlComponents.url else {
                                print("Invalid URL")
                                return
                            }
                            
                            var request = URLRequest(url: url)
                            request.httpMethod = "POST"
                            request.httpBody = jpegData
                            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                            
                            let (_, response) = try await URLSession.shared.data(for: request)
                            
                            if let httpResponse = response as? HTTPURLResponse,
                               (200...299).contains(httpResponse.statusCode) {
                                self.isUploaded = true
                                print("Video upload successful")
                                continuation.resume(returning: true)
                            } else {
                                print("Server responded with unexpected status code")
                                continuation.resume(returning: false)
                            }
                        } catch {
                            print("Error processing or uploading video: \(error)")
                            continuation.resume(returning: false)
                        }
                    }
                }
            }
        }
}
    
    func delete() async {
        guard let phAsset = phAsset else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets([phAsset] as NSArray)
            }
            print("PhotoAsset asset deleted: \(index ?? -1)")
        } catch (let error) {
            print("Failed to delete photo: \(error.localizedDescription)")
        }
    }
}

extension PhotoAsset: Equatable {
    static func ==(lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        (lhs.identifier == rhs.identifier) && (lhs.isFavorite == rhs.isFavorite)
    }
}

extension PhotoAsset: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
}

extension PHObject: Identifiable {
    public var id: String { localIdentifier }
}

