import SwiftUI

struct SetupView: View {
    @EnvironmentObject var config: ServerConfig
    var onConnected: (() -> Void)?

    @StateObject private var permissions = PermissionsManager.shared
    @State private var showCFFields = false
    @State private var notice: SetupNotice?
    @State private var isTestingConnection = false
    @State private var isConnecting = false
    @State private var favoriteName = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case serverURL
        case authToken
        case cloudflareClientId
        case cloudflareClientSecret
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SetupHeroView(isConfigured: config.isConfigured)

                    if let notice {
                        SetupNoticeView(notice: notice)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    SetupPanel(title: "Connection", systemImage: "network") {
                        SetupTextField(
                            title: "Server URL",
                            systemImage: "link",
                            prompt: "https://hermes.yourdomain.com",
                            text: $config.serverURL
                        )
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.URL)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .serverURL)
                        .onSubmit(beginConnect)
                        .accessibilityLabel("Hermes server URL")

                        Divider()

                        SetupTextField(
                            title: "Short name",
                            systemImage: "star",
                            prompt: "Local, Studio, Production",
                            text: $favoriteName
                        )
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)

                        Button {
                            saveFavorite()
                        } label: {
                            Label("Save as Favorite", systemImage: "star.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!canConnect)

                        if !config.favoriteConnections.isEmpty {
                            Divider()
                            FavoriteConnectionsView(
                                favorites: config.favoriteConnections,
                                currentURL: config.serverURL,
                                select: selectFavorite,
                                remove: config.removeFavorite
                            )
                        }

                        if !config.recentURLs.isEmpty {
                            Divider()
                            RecentConnectionsView(
                                recentURLs: config.recentURLs,
                                select: { url in
                                    config.serverURL = url
                                    favoriteName = URL(string: url)?.host ?? ""
                                    notice = nil
                                },
                                remove: config.removeRecent
                            )
                        }
                    }

                    SetupPanel(title: "Authentication", systemImage: "key") {
                        SetupSecureField(
                            title: "Hermes token",
                            systemImage: "person.badge.key",
                            prompt: "API token",
                            text: $config.hermesAuthToken
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.password)
                        .focused($focusedField, equals: .authToken)
                        .accessibilityLabel("Hermes API token")
                    }

                    SetupPanel(title: "Access Policy", systemImage: "lock.shield") {
                        Toggle(isOn: $showCFFields.animation(.snappy)) {
                            Label("Cloudflare Access", systemImage: "cloud")
                        }

                        if showCFFields {
                            Divider()
                            SetupTextField(
                                title: "Client ID",
                                systemImage: "number",
                                prompt: "CF-Access-Client-Id",
                                text: $config.cfClientId
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)
                            .focused($focusedField, equals: .cloudflareClientId)

                            Divider()
                            SetupSecureField(
                                title: "Client secret",
                                systemImage: "ellipsis.rectangle",
                                prompt: "CF-Access-Client-Secret",
                                text: $config.cfClientSecret
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.password)
                            .focused($focusedField, equals: .cloudflareClientSecret)
                        }
                    }

                    SetupPanel(title: "Native Capabilities", systemImage: "iphone.gen3.radiowaves.left.and.right") {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            PermissionTile(title: "Voice", systemImage: "waveform", status: permissions.speechRecognition)
                            PermissionTile(title: "Mic", systemImage: "mic", status: permissions.microphone)
                            PermissionTile(title: "Alerts", systemImage: "bell", status: permissions.notifications)
                            PermissionTile(title: "Files", systemImage: "folder", status: permissions.photoLibrary)
                        }

                        Button {
                            Task {
                                await permissions.requestAll()
                            }
                        } label: {
                            Label("Review Permissions", systemImage: "checkmark.shield")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if config.lastSuccessfulConnection != nil || !config.connectionLog.isEmpty {
                        SetupPanel(title: "Connection History", systemImage: "clock") {
                            ConnectionHistoryView(
                                lastSuccessfulConnection: config.lastSuccessfulConnection,
                                entries: Array(config.connectionLog.prefix(5))
                            )
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 120)
            }
            .background(Color(.systemGroupedBackground))
            .scrollDismissesKeyboard(.interactively)
            .animation(.snappy, value: notice)
            .navigationTitle("Hermes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SetupMainMenu(
                        hasSavedInput: hasSavedInput,
                        isTestingConnection: isTestingConnection,
                        testConnection: { Task { await testConnection() } },
                        reviewPermissions: { Task { await permissions.requestAll() } },
                        clearCredentials: clearCredentials
                    )
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                SetupActionBar(
                    canConnect: canConnect,
                    isTestingConnection: isTestingConnection,
                    isConnecting: isConnecting,
                    connect: beginConnect,
                    testConnection: { Task { await testConnection() } }
                )
            }
            .onAppear {
                showCFFields = !config.cfClientId.isEmpty || !config.cfClientSecret.isEmpty
                favoriteName = defaultFavoriteName
                permissions.refreshAll()
            }
        }
    }

    private var hasSavedInput: Bool {
        config.isConfigured
            || !config.serverURL.isEmpty
            || !config.hermesAuthToken.isEmpty
            || !config.cfClientId.isEmpty
            || !config.cfClientSecret.isEmpty
    }

    private var canConnect: Bool {
        !config.serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var defaultFavoriteName: String {
        if let favorite = config.favoriteConnections.first(where: { $0.serverURL == config.serverURL }) {
            return favorite.name
        }
        return URL(string: config.serverURL)?.host ?? ""
    }

    private func beginConnect() {
        Task {
            await connect()
        }
    }

    @MainActor
    private func connect() async {
        guard !isConnecting else { return }
        guard normalizeCurrentURL() else { return }
        guard validateCloudflareFields() else { return }

        isConnecting = true
        notice = .info("Checking Hermes before opening...")
        focusedField = nil

        let result = await runConnectionCheck()
        switch result {
        case .success:
            notice = .success("Connected. Opening Hermes...")
            try? await Task.sleep(nanoseconds: 250_000_000)
            withAnimation(.snappy) {
                config.saveAndMarkSuccessful()
            }
            isConnecting = false
            onConnected?()
        case .failure(let message):
            isConnecting = false
            notice = .error(message)
        }
    }

    @MainActor
    private func testConnection() async {
        guard !isTestingConnection else { return }
        guard normalizeCurrentURL() else { return }
        guard validateCloudflareFields() else { return }

        isTestingConnection = true
        notice = .info("Checking Hermes status...")
        defer { isTestingConnection = false }

        let result = await runConnectionCheck()
        switch result {
        case .success:
            notice = .success("Hermes responded. Tap Connect to open the app.")
        case .failure(let message):
            notice = .error(message)
        }
    }

    @MainActor
    private func runConnectionCheck() async -> ConnectionCheckResult {
        guard let baseURL = config.baseURL else {
            return .failure("Enter a valid Hermes server URL.")
        }

        var request = URLRequest(
            url: baseURL.appendingHermesPath("api/hermes/status"),
            timeoutInterval: 10
        )
        request.httpMethod = "GET"
        config.applyAuthentication(to: &request)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .failure("Hermes returned an unexpected network response.")
            }

            guard (200..<300).contains(httpResponse.statusCode) else {
                return .failure("Hermes returned HTTP \(httpResponse.statusCode). Check the URL and credentials.")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool,
               ok == false {
                return .failure("Hermes responded, but its status endpoint reported ok=false.")
            }

            return .success
        } catch {
            return .failure("Connection failed: \(error.localizedDescription)")
        }
    }

    private func clearCredentials() {
        config.clear()
        notice = .info("Saved credentials cleared.")
    }

    private func saveFavorite() {
        guard normalizeCurrentURL() else { return }
        config.favoriteCurrentConnection(named: favoriteName)
        favoriteName = defaultFavoriteName
        notice = .success("Favorite saved.")
    }

    private func selectFavorite(_ favorite: FavoriteConnection) {
        config.selectFavorite(favorite)
        favoriteName = favorite.name
        notice = .info("\(favorite.displayName) selected. Tap Connect to open it.")
    }

    @discardableResult
    private func normalizeCurrentURL() -> Bool {
        guard let normalizedURL = ServerConfig.normalizedServerURLString(from: config.serverURL) else {
            notice = .error("Enter a valid http:// or https:// URL.")
            return false
        }

        config.serverURL = normalizedURL
        return true
    }

    @discardableResult
    private func validateCloudflareFields() -> Bool {
        guard showCFFields else {
            config.cfClientId = ""
            config.cfClientSecret = ""
            return true
        }

        let clientId = config.cfClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let clientSecret = config.cfClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clientId.isEmpty == clientSecret.isEmpty else {
            notice = .error("Cloudflare Access requires both a client ID and client secret.")
            return false
        }

        config.cfClientId = clientId
        config.cfClientSecret = clientSecret
        return true
    }
}

private struct SetupHeroView: View {
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.blue.gradient)
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("Hermes")
                    .font(.title2.weight(.semibold))
                Text(isConfigured ? "Connection ready" : "Connect your agent")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: isConfigured ? "checkmark.circle.fill" : "circle.dotted")
                .font(.title2)
                .foregroundStyle(isConfigured ? .green : .secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum ConnectionCheckResult {
    case success
    case failure(String)
}

private struct SetupPanel<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(spacing: 12) {
                content
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SetupTextField: View {
    let title: String
    let systemImage: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(title, text: $text, prompt: Text(prompt))
                    .font(.body)
            }
        }
    }
}

private struct SetupSecureField: View {
    let title: String
    let systemImage: String
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                SecureField(title, text: $text, prompt: Text(prompt))
                    .font(.body)
            }
        }
    }
}

private struct RecentConnectionsView: View {
    let recentURLs: [String]
    let select: (String) -> Void
    let remove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(recentURLs, id: \.self) { url in
                HStack(spacing: 10) {
                    Button {
                        select(url)
                    } label: {
                        Label(url, systemImage: "clock.arrow.circlepath")
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(role: .destructive) {
                        remove(url)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove recent connection")
                }
                .font(.subheadline)
            }
        }
    }
}

private struct FavoriteConnectionsView: View {
    let favorites: [FavoriteConnection]
    let currentURL: String
    let select: (FavoriteConnection) -> Void
    let remove: (FavoriteConnection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Favorites")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(favorites) { favorite in
                HStack(spacing: 10) {
                    Button {
                        select(favorite)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: favorite.serverURL == currentURL ? "checkmark.circle.fill" : "star.fill")
                                .foregroundStyle(favorite.serverURL == currentURL ? .green : .yellow)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(favorite.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(favorite.serverURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button(role: .destructive) {
                        remove(favorite)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove favorite")
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct ConnectionHistoryView: View {
    let lastSuccessfulConnection: ConnectionLogEntry?
    let entries: [ConnectionLogEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let lastSuccessfulConnection {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last successful")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Label {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(lastSuccessfulConnection.title)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(lastSuccessfulConnection.serverURL)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(lastSuccessfulConnection.occurredAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            if !entries.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent activity")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(entries) { entry in
                        Label {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.title)
                                    .font(.caption.weight(.semibold))
                                    .lineLimit(1)
                                Text(entry.detail ?? entry.serverURL)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text(entry.occurredAt.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        } icon: {
                            Image(systemName: entry.kind == .connection ? "network" : "safari")
                                .foregroundStyle(entry.kind == .connection ? .blue : .secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct PermissionTile: View {
    let title: String
    let systemImage: String
    let status: PermissionsManager.Status

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(status.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(status.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SetupActionBar: View {
    let canConnect: Bool
    let isTestingConnection: Bool
    let isConnecting: Bool
    let connect: () -> Void
    let testConnection: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: testConnection) {
                    if isTestingConnection {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Test", systemImage: "network")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(!canConnect || isTestingConnection || isConnecting)

                Button(action: connect) {
                    if isConnecting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Opening")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Connect", systemImage: "bolt.horizontal.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canConnect || isTestingConnection || isConnecting)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

private struct SetupMainMenu: View {
    let hasSavedInput: Bool
    let isTestingConnection: Bool
    let testConnection: () -> Void
    let reviewPermissions: () -> Void
    let clearCredentials: () -> Void

    var body: some View {
        Menu {
            Button(action: testConnection) {
                Label("Test Connection", systemImage: "network")
            }
            .disabled(isTestingConnection)

            Button(action: reviewPermissions) {
                Label("Review Permissions", systemImage: "checkmark.shield")
            }

            if hasSavedInput {
                Divider()
                Button(role: .destructive, action: clearCredentials) {
                    Label("Clear Saved Credentials", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.title3)
        }
        .accessibilityLabel("Main menu")
    }
}

private struct SetupNotice: Equatable {
    enum Kind {
        case success
        case error
        case info
    }

    let kind: Kind
    let message: String

    static func success(_ message: String) -> SetupNotice {
        SetupNotice(kind: .success, message: message)
    }

    static func error(_ message: String) -> SetupNotice {
        SetupNotice(kind: .error, message: message)
    }

    static func info(_ message: String) -> SetupNotice {
        SetupNotice(kind: .info, message: message)
    }
}

private struct SetupNoticeView: View {
    let notice: SetupNotice

    var body: some View {
        Label {
            Text(notice.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var systemImage: String {
        switch notice.kind {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }

    private var color: Color {
        switch notice.kind {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        }
    }
}

private extension PermissionsManager.Status {
    var title: String {
        switch self {
        case .notDetermined:
            return "Not Set"
        case .granted:
            return "Allowed"
        case .denied:
            return "Denied"
        }
    }

    var color: Color {
        switch self {
        case .notDetermined:
            return .secondary
        case .granted:
            return .green
        case .denied:
            return .red
        }
    }
}
