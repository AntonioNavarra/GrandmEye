//
//  SettingsView.swift
//  LenteFacile
//
//  Created by Antonio Navarra on 25/11/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color("BackgroundPrimary").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // SEZIONE A: Ingrandimento
                        SettingsCard(title: Localization.magnificationSection, icon: "magnifyingglass") {
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("\(Localization.defaultZoom): \(String(format: "%.1fx", viewModel.magSettings.defaultZoomLevel))")
                                        .font(.body)
                                        .foregroundColor(.white)
                                    
                                    Slider(
                                        value: $viewModel.magSettings.defaultZoomLevel,
                                        in: 1.0...5.0,
                                        step: 0.5
                                    ) { editing in
                                        if editing { HapticManager.shared.selectionChanged() }
                                    }
                                    .accentColor(Color("AccentColor"))
                                }
                                
                                Toggle(Localization.rememberZoom, isOn: $viewModel.magSettings.rememberLastZoom)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                            }
                        }
                        
                        // SEZIONE B: Audio e Feedback
                        SettingsCard(title: Localization.audioSection, icon: "waveform") {
                            VStack(spacing: 16) {
                                Toggle(Localization.soundInterface, isOn: $viewModel.appSettings.soundEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                                
                                Toggle(Localization.hapticFeedback, isOn: $viewModel.appSettings.hapticEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                            }
                        }
                        
                        // RIMOSSO: Sezione Visual Appearance
                        
                        // SEZIONE C: Info e Reset
                        VStack(spacing: 20) {
                            Text(viewModel.appVersion)
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary"))
                            
                            Button(action: {
                                viewModel.resetAllSettings()
                            }) {
                                Text(Localization.resetSettings)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color("BackgroundSecondary"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle(Localization.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(Localization.close) {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    }
                    .foregroundColor(Color("AccentColor"))
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
