import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroundPrimary").ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        
                        // Language Selection
                        SettingsCard(title: "settings_language", icon: "character.bubble") {
                            Picker("settings_language", selection: $viewModel.appSettings.languageCode) {
                                ForEach(viewModel.languages, id: \.code) { lang in
                                    Text(lang.name).tag(lang.code)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.vertical, 8)
                        }
                        
                        // Magnification settings
                        SettingsCard(title: "settings_magnification", icon: "magnifyingglass") {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("\(String(localized: "settings_default_zoom")): \(String(format: "%.1fx", viewModel.magSettings.defaultZoomLevel))")
                                    .foregroundColor(.white)
                                
                                Slider(value: $viewModel.magSettings.defaultZoomLevel, in: 1.0...5.0, step: 0.5)
                                    .accentColor(Color("AccentColor"))
                                
                                Toggle("settings_remember_zoom", isOn: $viewModel.magSettings.rememberLastZoom)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                            }
                        }
                        
                        // Feedback & Accessibility
                        SettingsCard(title: "settings_sensory_feedback", icon: "waveform") {
                            VStack(spacing: 16) {
                                Toggle("settings_interface_sounds", isOn: $viewModel.appSettings.soundEnabled)
                                Toggle("settings_haptic_feedback", isOn: $viewModel.appSettings.hapticEnabled)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                        }
                        
                        // Reset & Info
                        VStack(spacing: 20) {
                            Text(viewModel.appVersion)
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Button(action: viewModel.resetAllSettings) {
                                Text("settings_reset")
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color("BackgroundSecondary"))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("settings_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("settings_close") {
                        HapticManager.shared.buttonTap()
                        dismiss()
                    }
                    .foregroundColor(Color("AccentColor"))
                }
            }
        }
    }
}
