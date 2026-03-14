import SwiftUI

struct MainView: View {
    @State private var selectedModule: AppModule = .dashboard
    @State private var isHoveringModule: AppModule?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                }
                Text("DevCleaner")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)

            // Module list
            VStack(spacing: 2) {
                ForEach(AppModule.allCases) { module in
                    sidebarButton(module)
                }
            }
            .padding(.horizontal, 8)

            Spacer()

            // Version
            Text("v2.0")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
                .padding(.bottom, 8)
        }
        .frame(minWidth: 170, maxWidth: 200)
    }

    private func sidebarButton(_ module: AppModule) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedModule = module
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: module.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(selectedModule == module ? .white : .secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 1) {
                    Text(module.rawValue)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(selectedModule == module ? .white : .primary)

                    Text(module.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(selectedModule == module ? .white.opacity(0.7) : .secondary.opacity(0.6))
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        selectedModule == module
                            ? LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(
                                colors: isHoveringModule == module
                                    ? [Color.primary.opacity(0.05)]
                                    : [.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHoveringModule = hovering ? module : nil
        }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detailView: some View {
        switch selectedModule {
        case .dashboard:
            DashboardView()
        case .smartClean:
            SmartCleanView()
        case .largeFiles:
            LargeFilesView()
        case .appManager:
            AppManagerView()
        case .ram:
            RAMView()
        }
    }
}
