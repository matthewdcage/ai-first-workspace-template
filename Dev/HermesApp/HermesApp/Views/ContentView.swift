import SwiftUI

struct ContentView: View {
    @EnvironmentObject var config: ServerConfig

    var body: some View {
        if config.isConfigured {
            WebView()
        } else {
            SetupView()
        }
    }
}
