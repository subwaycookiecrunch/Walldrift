import SwiftUI

struct SettingsView: View {
    @ObservedObject var autoRotateService = AutoRotateService.shared
    @ObservedObject var backgroundFeedService = BackgroundFeedService.shared
    @State private var cacheSize: String = "Calculating..."
    
    let intervals: [TimeInterval] = [
        900, // 15 min
        1800, // 30 min
        3600, // 1 hr
        10800, // 3 hr
        86400 // Daily
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Auto-Rotate Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Auto-Rotate Interval")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Picker("Interval", selection: $autoRotateService.interval) {
                    Text("15 Minutes").tag(TimeInterval(900))
                    Text("30 Minutes").tag(TimeInterval(1800))
                    Text("1 Hour").tag(TimeInterval(3600))
                    Text("3 Hours").tag(TimeInterval(10800))
                    Text("Daily").tag(TimeInterval(86400))
                }
                .labelsHidden()
                
                Toggle("Always Use Latest from Feed", isOn: $autoRotateService.rotateFromFeed)
                    .toggleStyle(.checkbox)
            }
            
            Divider()
            
            // Live Feed Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Live Feed (Background Polling)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Poll Interval")
                    Spacer()
                    Picker("Poll Interval", selection: $backgroundFeedService.pollInterval) {
                        Text("5 Minutes").tag(TimeInterval(300))
                        Text("15 Minutes").tag(TimeInterval(900))
                        Text("30 Minutes").tag(TimeInterval(1800))
                        Text("1 Hour").tag(TimeInterval(3600))
                    }
                    .labelsHidden()
                }
                
                Toggle("Notify on New Wallpapers", isOn: $backgroundFeedService.notifyOnNew)
                    .toggleStyle(.checkbox)
                
                Toggle("Instant Swap on New", isOn: $backgroundFeedService.autoSetOnNew)
                    .toggleStyle(.checkbox)
                
                Button(action: {
                    backgroundFeedService.clearFeedHistory()
                }) {
                    Text("Clear Feed History")
                        .foregroundColor(.red)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            Divider()
            
            // Storage Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Storage")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text("Cache Size:")
                    Spacer()
                    Text(cacheSize)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    Task {
                        await ImageCacheService.shared.clearCache()
                        await updateCacheSize()
                    }
                }) {
                    Text("Clear Cache")
                        .foregroundColor(.white)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                        .background(Color.blue)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            Task {
                await updateCacheSize()
            }
        }
    }
    
    private func updateCacheSize() async {
        let size = await ImageCacheService.shared.getCacheSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        await MainActor.run {
            self.cacheSize = formatter.string(fromByteCount: Int64(size))
        }
    }
}
