import SwiftUI
import AVFoundation
import CoreLocation
import HealthKit

struct SettingsView: View {
    @Environment(Settings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var previewCoach = AudioCoach()
    @State private var healthStatus = HealthStore.shared.authorizationStatus

    private let voices = SpeechCoach.availableVoices()

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("Voice", selection: $settings.voiceIdentifier) {
                        Text("Automatic").tag(String?.none)
                        ForEach(voices, id: \.identifier) { v in
                            Text([v.name, SpeechCoach.genderLabel(v), SpeechCoach.qualityLabel(v)].compactMap { $0 }.joined(separator: " · "))
                                .tag(String?.some(v.identifier))
                        }
                    }
                    Button("Preview") {
                        previewCoach.voiceIdentifier = settings.voiceIdentifier
                        previewCoach.chimesEnabled = settings.chimesEnabled
                        previewCoach.preview("Run for 90 seconds.")
                    }
                    Toggle("Chimes before cues", isOn: $settings.chimesEnabled)
                } header: {
                    Text("Voice")
                } footer: {
                    Text("Higher quality voices can be downloaded in Settings → Accessibility → Spoken Content → Voices.")
                }

                Section {
                    Toggle("Warmup drills before a run", isOn: $settings.warmupDrills)
                } header: {
                    Text("Warmup")
                } footer: {
                    Text("\(WarmupRoutine.standard.drills.map(\.name).joined(separator: ", ")). About \(Session.durationWords(WarmupRoutine.standard.totalSeconds)), before the run and its warmup walk. Not saved to Health.")
                }

                Section("Units") {
                    Picker("Distance", selection: $settings.useMiles) {
                        Text("Miles").tag(true)
                        Text("Kilometers").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    LabeledContent("Location", value: locationLabel)
                    LabeledContent("Health", value: healthLabel)
                    if healthStatus == .notDetermined && HealthStore.shared.isAvailable {
                        Button("Allow saving workouts to Health") {
                            Task {
                                await HealthStore.shared.requestAuthorization()
                                healthStatus = HealthStore.shared.authorizationStatus
                            }
                        }
                    }
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("With music playing, headphone buttons control the music app. Pause the run from the phone or the Live Activity.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var locationLabel: String {
        switch RunTracker.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: "Allowed"
        case .denied, .restricted: "Denied"
        default: "Not asked yet"
        }
    }

    private var healthLabel: String {
        guard HealthStore.shared.isAvailable else { return "Unavailable" }
        return switch healthStatus {
        case .sharingAuthorized: "Allowed"
        case .sharingDenied: "Denied"
        default: "Not asked yet"
        }
    }
}
