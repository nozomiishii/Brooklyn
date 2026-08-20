import SwiftUI

struct ContentView: View {
    @State private var registrar = ExtensionRegistrar()

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
                    registrar.registerAndRefresh()
                }
            }

            if registrar.legacySaverExists {
                Button("Remove Legacy Brooklyn.saver", role: .destructive) {
                    registrar.removeLegacySaver()
                }
            }
        }
        .padding(24)
        .frame(width: 480, alignment: .leading)
        .task {
            registrar.registerAndRefresh()
        }
    }
}
