#if DEBUG
import SwiftUI

struct SetupView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SetupView()
                .environmentObject(ServerConfig.preview())
                .previewDisplayName("Setup")

            SetupView()
                .environmentObject(ServerConfig.preview(serverURL: "https://hermes.example.com"))
                .previewDisplayName("Setup Configured")
        }
    }
}
#endif
