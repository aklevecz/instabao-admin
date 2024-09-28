//
//  ContentView.swift
//  instabao-admin
//
//  Created by Ariel Klevecz on 9/27/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var model = DataModel()

    var body: some View {
        NavigationStack {
            PhotoCollectionView(photoCollection: model.photoCollection)
                .task {
                    await model.loadPhotos()
                    await model.loadThumbnail()
                }
        }
    }
}

#Preview {
    ContentView()
}
