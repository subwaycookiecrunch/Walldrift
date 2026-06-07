import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @StateObject private var viewModel = MenuBarViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("WallDrift")
                    .font(.headline)
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                }
                .buttonStyle(.plain)
            }
            .padding([.horizontal, .top])
            .padding(.bottom, 12)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 16) {
                    // showing background polling status and timer
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "livephoto")
                                .foregroundColor(BackgroundFeedService.shared.isPolling ? .green : .secondary)
                            Text("Live Feed Status")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            if BackgroundFeedService.shared.newItemCount > 0 {
                                Text("\(BackgroundFeedService.shared.newItemCount) new")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green)
                                    .cornerRadius(10)
                            }
                        }
                        
                        if let lastUpdated = BackgroundFeedService.shared.lastUpdated {
                            Text("Last Poll: \(formatTime(lastUpdated))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Last Poll: Never")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        CountdownText()
                    }
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $viewModel.isRotating) {
                            Text("Auto-Rotate Wallpapers")
                        }
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.isRotating) { newValue in
                            AutoRotateService.shared.isEnabled = newValue
                        }
                        
                        Button(action: {
                            viewModel.nextWallpaper()
                        }) {
                            HStack {
                                Image(systemName: "forward.end.fill")
                                Text("Next Wallpaper")
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: {
                            // asyncAfter 0.1s is a hack but without it macOS closes the window immediately
                            // when the menuBarExtra popover loses focus.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                openWindow(id: "browser")
                                NSApp.activate(ignoringOtherApps: true)
                            }
                        }) {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("Open Browser")
                                Spacer()
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Divider()
                    
                    SettingsView()
                }
                .padding()
            }
        }
        .frame(width: 320, height: 480)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct CountdownText: View {
    @State private var timeRemaining: String = ""
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeRemaining)
            .font(.caption)
            .foregroundColor(.secondary)
            .onReceive(timer) { _ in
                updateCountdown()
            }
            .onAppear {
                updateCountdown()
            }
    }
    
    private func updateCountdown() {
        let service = BackgroundFeedService.shared
        guard let lastUpdated = service.lastUpdated else {
            timeRemaining = "Next Poll: Waiting..."
            return
        }
        let nextPollDate = lastUpdated.addingTimeInterval(service.pollInterval)
        let diff = nextPollDate.timeIntervalSince(Date())
        if diff <= 0 {
            timeRemaining = "Next Poll: Polling now..."
        } else {
            let minutes = Int(diff) / 60
            let seconds = Int(diff) % 60
            timeRemaining = String(format: "Next Poll in: %02dm %02ds", minutes, seconds)
        }
    }
}
