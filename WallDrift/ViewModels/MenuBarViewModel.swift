import Foundation
import AppKit
import Combine

// simple view model for menu bar UI, mostly just forwards commands to the services
@MainActor
class MenuBarViewModel: ObservableObject {
    @Published var isRotating: Bool = AutoRotateService.shared.isEnabled
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        AutoRotateService.shared.$isEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.isRotating = enabled
            }
            .store(in: &cancellables)
    }
    
    func toggleAutoRotate() {
        AutoRotateService.shared.isEnabled.toggle()
    }
    
    func nextWallpaper() {
        Task {
            await AutoRotateService.shared.rotateNow()
        }
    }
}
