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
                        SettingsCard(title: "settings_magnification", icon: "magnifyingglass") {
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("\(String(localized: "settings_default_zoom")): \(String(format: "%.1fx", viewModel.magSettings.defaultZoomLevel))")
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
                                
                                Toggle("settings_remember_zoom", isOn: $viewModel.magSettings.rememberLastZoom)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                            }
                        }
                        
                        SettingsCard(title: "settings_sensory_feedback", icon: "waveform") {
                            VStack(spacing: 16) {
                                Toggle("settings_interface_sounds", isOn: $viewModel.appSettings.soundEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                                
                                Toggle("settings_haptic_feedback", isOn: $viewModel.appSettings.hapticEnabled)
                                    .toggleStyle(SwitchToggleStyle(tint: Color("AccentColor")))
                            }
                        }
                        
                        VStack(spacing: 20) {
                            Text(viewModel.appVersion)
                                .font(.caption)
                                .foregroundColor(Color("TextSecondary"))
                            
                            Button(action: {
                                viewModel.resetAllSettings()
                            }) {
                                Text("settings_reset")
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
            .navigationTitle("settings_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("settings_close") {
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
