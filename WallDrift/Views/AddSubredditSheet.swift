import SwiftUI

struct AddSubredditSheet: View {
    @ObservedObject var viewModel: BrowserViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var subredditName = ""
    @State private var isLoading = false
    @State private var errorMsg: String? = nil
    @State private var validatedMetadata: SubredditAboutData? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Add Custom Subreddit")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Subreddit Name")
                    .font(.headline)
                
                HStack {
                    Text("r/")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    
                    TextField("wallpapers", text: $subredditName)
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                        .onSubmit {
                            validateSubreddit()
                        }
                    
                    Button("Validate") {
                        validateSubreddit()
                    }
                    .disabled(subredditName.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Content Area
            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Validating subreddit...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: 180)
                } else if let error = errorMsg {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxHeight: 180)
                } else if let metadata = validatedMetadata {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            if let iconURLString = metadata.cleanIconURL, let iconURL = URL(string: iconURLString) {
                                CachedAsyncImage(url: iconURL)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "globe")
                                    .font(.system(size: 32))
                                    .frame(width: 50, height: 50)
                                    .background(Color.secondary.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(metadata.title)
                                    .font(.headline)
                                Text("r/\(metadata.displayName)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                if let subs = metadata.subscribers {
                                    Text("\(formatSubscribers(subs)) subscribers")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        if let desc = metadata.publicDescription, !desc.isEmpty {
                            Text(desc)
                                .font(.body)
                                .lineLimit(3)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                } else {
                    VStack {
                        Text("Enter a subreddit name above to search and validate it.")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxHeight: 180)
                }
            }
            .frame(height: 180)
            
            Spacer()
            
            Divider()
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Add Source") {
                    addSource()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(validatedMetadata == nil || isLoading)
            }
            .padding([.horizontal, .bottom])
        }
        .frame(width: 400, height: 380)
    }
    
    private func validateSubreddit() {
        let name = subredditName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        isLoading = true
        errorMsg = nil
        validatedMetadata = nil
        
        Task {
            do {
                let metadata = try await RedditService.shared.validateSubreddit(name: name)
                validatedMetadata = metadata
            } catch {
                errorMsg = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    private func addSource() {
        guard let metadata = validatedMetadata else { return }
        Task {
            do {
                try await viewModel.addCustomSubreddit(name: metadata.displayName)
                dismiss()
            } catch {
                errorMsg = error.localizedDescription
            }
        }
    }
    
    private func formatSubscribers(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }
}
