import SwiftUI

struct SetupView: View {
    @EnvironmentObject var config: ServerConfig
    @State private var showCFFields = false
    @State private var validationError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Hermes Server") {
                    TextField("https://hermes.yourdomain.com", text: $config.serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    TextField("Auth Token (from Hermes Settings)", text: $config.hermesAuthToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Hermes Authentication")
                } footer: {
                    Text("Found in Hermes Studio → Settings → Account → API Token")
                        .font(.caption)
                }

                Section {
                    Toggle("Cloudflare Access (optional)", isOn: $showCFFields.animation())
                    if showCFFields {
                        TextField("CF-Access-Client-Id", text: $config.cfClientId)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("CF-Access-Client-Secret", text: $config.cfClientSecret)
                    }
                } header: {
                    Text("Cloudflare Access")
                } footer: {
                    Text("Enable if your tunnel is protected by Cloudflare Access policies.")
                        .font(.caption)
                }

                if let error = validationError {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }

                Section {
                    Button("Connect to Hermes") {
                        connect()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(config.serverURL.isEmpty)
                }
            }
            .navigationTitle("Hermes Setup")
        }
    }

    private func connect() {
        guard let url = URL(string: config.serverURL), url.scheme?.hasPrefix("http") == true else {
            validationError = "Enter a valid https:// URL."
            return
        }
        validationError = nil
        config.save()
    }
}
