import SwiftUI

struct OverlayView: View {
    @ObservedObject var model: WorkspaceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider().opacity(0.55)

            if let error = model.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.red).padding(.vertical, 16)
            } else {
                workspaceList
            }
        }
        .padding(18)
        .frame(width: 620)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
    }

    private var workspaceList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(model.workspaces) { workspace in
                        WorkspaceRowView(
                            workspace: workspace,
                            isExpanded: model.expandedWorkspaceID == workspace.id,
                            isSelected: model.selection == .workspace(workspace.id)
                        )
                        .id(WorkspaceSelection.workspace(workspace.id))

                        if model.expandedWorkspaceID == workspace.id {
                            ForEach(workspace.windows) { window in
                                WindowRowView(
                                    window: window,
                                    isSelected: model.selection == .window(window.id)
                                )
                                .id(WorkspaceSelection.window(window.id))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 500)
            .onChange(of: model.selection) { _, selection in
                guard let selection else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(selection, anchor: .center)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 18, weight: .semibold)).foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 1) {
                Text("Workspaces").font(.system(size: 17, weight: .semibold))
                Text("AeroSpace").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text("←→ Collapse/Expand   ↑↓ Navigate   ↩ Switch")
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
        }
    }
}

private struct WorkspaceRowView: View {
    let workspace: Workspace
    let isExpanded: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: disclosureSymbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(workspace.isEmpty ? .quaternary : .secondary)
                .frame(width: 10)
            activeIndicator
            Text(workspace.id)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit().frame(width: 24, alignment: .leading)

            if workspace.isEmpty {
                Text("Empty").font(.callout).foregroundStyle(.tertiary)
            } else {
                appSummary
            }

            Spacer(minLength: 8)
            countBadge
        }
        .padding(.horizontal, 10).frame(height: 36).contentShape(Rectangle())
        .background(SelectionBackground(isSelected: isSelected))
        .opacity(workspace.isEmpty && !isSelected ? 0.52 : 1)
        .animation(.easeOut(duration: 0.12), value: isSelected)
    }

    private var disclosureSymbol: String {
        workspace.isEmpty ? "circle" : (isExpanded ? "chevron.down" : "chevron.right")
    }

    private var activeIndicator: some View {
        Circle().fill(workspace.isActive ? Color.accentColor : .clear)
            .overlay(Circle().stroke(workspace.isActive ? Color.accentColor : .secondary.opacity(0.3), lineWidth: 1))
            .frame(width: 7, height: 7)
    }

    private var appSummary: some View {
        HStack(spacing: 7) {
            ForEach(workspace.applications.prefix(4)) { application in
                Image(nsImage: AppIconProvider.icon(for: application.name))
                    .resizable().scaledToFit().frame(width: 19, height: 19).help(application.name)
            }
            Text(workspace.applications.map(appLabel).joined(separator: ", "))
                .font(.system(size: 13)).lineLimit(1).truncationMode(.tail)
        }
    }

    private var countBadge: some View {
        Text(workspace.windowCount == 1 ? "1 window" : "\(workspace.windowCount) windows")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(workspace.isEmpty ? .tertiary : .secondary)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(.primary.opacity(workspace.isEmpty ? 0.03 : 0.07), in: Capsule())
    }

    private func appLabel(_ application: WorkspaceApplication) -> String {
        application.windowCount > 1 ? "\(application.name) ×\(application.windowCount)" : application.name
    }
}

private struct WindowRowView: View {
    let window: AeroSpaceWindow
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            Circle().stroke(.secondary.opacity(0.55), lineWidth: 1).frame(width: 7, height: 7)
            Image(nsImage: AppIconProvider.icon(for: window.applicationName))
                .resizable().scaledToFit().frame(width: 17, height: 17)
            Text(window.applicationName)
                .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Text("—").foregroundStyle(.quaternary)
            Text(window.displayTitle).font(.system(size: 12)).lineLimit(1).truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.leading, 48).padding(.trailing, 10).frame(height: 31)
        .contentShape(Rectangle())
        .background(SelectionBackground(isSelected: isSelected))
    }
}

private struct SelectionBackground: View {
    let isSelected: Bool
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.2) : .clear)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : .clear, lineWidth: 1)
            }
    }
}
