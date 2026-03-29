import SwiftUI

/// SwiftUI-based configuration sheet for selecting animations and playback options.
struct ConfigureSheet: View {
    @ObservedObject private var viewModel: ConfigureSheetViewModel

    init(manager: BrooklynManager) {
        self._viewModel = ObservedObject(wrappedValue: ConfigureSheetViewModel(manager: manager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            animationList
            Divider()
            playbackOptions
            Divider()
            footer
        }
        .frame(width: 480, height: 560)
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Text("Brooklyn")
                .font(.title.bold())
            Text("Inspired by Apple's October 30th event.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Animation List

    private var animationList: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Select All") { viewModel.selectAll() }
                Button("Remove All") { viewModel.removeAll() }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            List {
                ForEach(Animation.allCases) { animation in
                    AnimationRow(
                        animation: animation,
                        isSelected: viewModel.isSelected(animation),
                        onToggle: { viewModel.toggle(animation) }
                    )
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Playback Options

    private var playbackOptions: some View {
        HStack(spacing: 20) {
            Picker("Loops:", selection: $viewModel.numberOfLoops) {
                Text("Infinite").tag(0)
                ForEach(1...10, id: \.self) { count in
                    Text("\(count)").tag(count)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)

            Toggle("Random Order", isOn: $viewModel.randomOrder)
        }
        .padding()
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("v1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Close") {
                guard let window = NSApp.keyWindow else { return }
                window.sheetParent?.endSheet(window)
            }
        }
        .padding()
    }
}

// MARK: - Animation Row

private struct AnimationRow: View {
    let animation: Animation
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Toggle(isOn: Binding(get: { isSelected }, set: { _ in onToggle() })) {
                Text(animation.displayName)
            }
            .toggleStyle(.checkbox)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
    }
}
