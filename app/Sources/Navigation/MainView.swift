import SwiftUI

struct MainView: View {
    @State private var selectedModule: AppModule = .dashboard
    @State private var hoveringModule: AppModule?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detailView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(red: 0.11, green: 0.11, blue: 0.14))
        .preferredColorScheme(.dark)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Logo
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 26, height: 26)
                    Image(systemName: "paintbrush.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("DevCleaner")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)

            // Modules
            VStack(spacing: 2) {
                ForEach(AppModule.allCases) { module in
                    sidebarItem(module)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            Text("v2.0")
                .font(.system(size: 9))
                .foregroundStyle(.quaternary)
                .padding(.bottom, 10)
        }
        .frame(width: 180)
        .background(Color(red: 0.09, green: 0.09, blue: 0.12))
    }

    private func sidebarItem(_ module: AppModule) -> some View {
        let isSelected = selectedModule == module
        let isHovering = hoveringModule == module

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedModule = module
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: module.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(module.rawValue)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text(module.subtitle)
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            : AnyShapeStyle(Color.primary.opacity(isHovering ? 0.06 : 0))
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveringModule = hovering ? module : nil
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
        case .diskMap:
            DiskMapView()
        case .largeFiles:
            LargeFilesView()
        case .appManager:
            AppManagerView()
        case .startup:
            StartupView()
        case .network:
            NetworkView()
        case .ram:
            RAMView()
        }
    }
}
