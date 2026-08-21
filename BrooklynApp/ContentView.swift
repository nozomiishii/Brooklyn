import SwiftUI

struct ContentView: View {
    private let registrar = ExtensionRegistrar.shared
    private let iconController = AppIconController.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Brooklyn")
                .font(.largeTitle.bold())

            Text("""
            Select Brooklyn in System Settings > Wallpaper > Screen Saver.
            The screen saver extension is registered automatically when this app launches.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)

            Label(
                registrar.isRegistered ? "Extension registered" : "Extension not registered yet",
                systemImage: registrar.isRegistered ? "checkmark.circle.fill" : "exclamationmark.triangle"
            )
            .foregroundStyle(registrar.isRegistered ? Color.green : Color.orange)

            HStack {
                Button("Open Screen Saver Settings") {
                    registrar.openScreenSaverSettings()
                }
                .keyboardShortcut(.defaultAction)

                Button("Re-register Extension") {
                    Task { await registrar.registerAndRefresh() }
                }
            }

            Divider()

            Picker("App Icon", selection: Binding(
                get: { iconController.selected },
                set: { iconController.select($0) }
            )) {
                ForEach(AppIcon.allCases) { icon in
                    Text(icon.displayName).tag(icon)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            if let error = iconController.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
        .frame(width: 480, alignment: .leading)
        .task {
            await registrar.refresh()
        }
    }
}
