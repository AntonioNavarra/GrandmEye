//
//  SettingsCard.swift
//  EasyReader
//
//  Created by Antonio Navarra on 25/11/25.
//

import SwiftUI

/// Un contenitore stilizzato per gruppi di impostazioni.
struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header Card
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color("AccentColor"))
                    .font(.headline)
                
                Text(title.uppercased())
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(Color("TextSecondary"))
            }
            
            Divider()
                .background(Color("Divider"))
            
            // Contenuto
            content
        }
        .padding()
        .background(Color("BackgroundSecondary"))
        .cornerRadius(16)
        .padding(.horizontal)
    }
}
