import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct fawfittApp: App {
    @StateObject private var appModel = AppViewModel()
    private let persistence = PersistenceController.shared

    init() {
        configureFirebaseIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .preferredColorScheme(.dark)
        }
    }

    private func configureFirebaseIfAvailable() {
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() == nil else { return }

        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            print("Firebase skipped: GoogleService-Info.plist is not in the app bundle.")
            return
        }

        FirebaseApp.configure()
        #else
        print("Firebase skipped: FirebaseCore package is not available to this target.")
        #endif
    }
}
