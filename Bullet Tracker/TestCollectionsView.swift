//
//  TestCollectionsView.swift
//  Bullet Tracker
//
//  Created by Dustin Brown on 5/12/25.
//


import SwiftUI

struct TestCollectionsView: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("This is a test collections view")
                    .font(.title)
                    .padding()
                
                Image(systemName: "folder.fill")
                    .font(.system(size: 100))
                    .foregroundColor(.blue)
                    .padding()
                
                Button("Test Button") {
                    print("Button tapped")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Spacer()
            }
            .navigationTitle("Test Collections")
        }
    }
}