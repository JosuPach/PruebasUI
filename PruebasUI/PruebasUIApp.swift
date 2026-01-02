import SwiftUI

@main
struct TuProyectoApp: App {
    // Declara aquí el storage para el StateObject
    @StateObject private var communicator = BLECommunicator()

    var body: some Scene {
        WindowGroup {
            AppContainerView(communicator: communicator)
        }
    }
}
