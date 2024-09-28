//
//  PhotoLibrary.swift
//  instabao-admin
//
//  Created by Ariel Klevecz on 9/27/24.
//

/*
See the License.txt file for this sample’s licensing information.
*/

import Photos

class PhotoLibrary {

    static func checkAuthorization() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
//            print("Photo library access authorized.")
            return true
        case .notDetermined:
//            print("Photo library access not determined.")
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite) == .authorized
        case .denied:
//            print("Photo library access denied.")
            return false
        case .limited:
//            print("Photo library access limited.")
            return false
        case .restricted:
//            print("Photo library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
}

//fileprivate let logger = Logger(subsystem: "com.apple.swiftplaygroundscontent.capturingphotos", category: "PhotoLibrary")
