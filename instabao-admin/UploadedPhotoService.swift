//
//  UploadedPhotoService.swift
//  instabao-admin
//
//  Created by Ariel Klevecz on 9/27/24.
//

import Foundation

struct ItemData: Codable {
    let uploaded: String
    let key: String
}

class UploadedPhotosService {
    static let shared = UploadedPhotosService()

    private(set) var uploadedPhotos: [String] = []

    func fetchUploadedPhotos() async {
        do {
            let fetchedPhotos = try await fetchFromServer()
            DispatchQueue.main.async {
                self.uploadedPhotos = fetchedPhotos
            }
        } catch {
            print("Fetch failed: \(error.localizedDescription)")
        }
    }

    func fetchFromServer() async -> [String] {
        let endpoint = "https://insta.baos.haus/instabao/images"
        print("Fetching from \(endpoint)")
        guard let url = URL(string: endpoint) else {
            print("Invalid URL")
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let photoIds = try JSONDecoder().decode([ItemData].self, from: data)
            let keys = photoIds.map { $0.key.replacingOccurrences(of: "baostagram/", with: "") }
            return keys
        } catch {
            print("Fetch failed: \(error.localizedDescription)")
            return []
        }
    }
}
