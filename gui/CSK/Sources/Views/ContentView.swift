import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: SkillManager
    @State private var selectedPack: String?
    @State private var selectedSkill: Skill?

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            skillList
        } detail: {
            detailPane
        }
        .searchable(text: $manager.searchText, prompt: "스킬 검색...")
        .touchBar {
            TouchBarView(selectedPack: $selectedPack)
        }
        .onAppear {
            if selectedPack == nil {
                selectedPack = manager.packs.first?.id
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(manager.filteredPacks, selection: $selectedPack) { pack in
            PackRow(pack: pack)
                .tag(pack.id)
        }
        .listStyle(.sidebar)
        .navigationTitle("CSK")
        .toolbar {
            ToolbarItem {
                Button(action: { manager.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("새로고침")
            }
        }
    }

    // MARK: - Skill List

    private var skillList: some View {
        Group {
            if let packId = selectedPack,
               let pack = manager.filteredPacks.first(where: { $0.id == packId }) {
                VStack(spacing: 0) {
                    packHeader(pack)
                    Divider()
                    List(pack.skills, selection: $selectedSkill) { skill in
                        SkillRow(skill: skill) {
                            manager.toggleSkill(skill)
                        }
                        .tag(skill)
                    }
                    .listStyle(.inset)
                }
                .navigationTitle(pack.id)
            } else {
                Text("팩을 선택하세요")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func packHeader(_ pack: SkillPack) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pack.id)
                    .font(.title2.bold())
                Text(pack.descriptionKo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(pack.enabledCount)/\(pack.totalCount)")
                .font(.title3.monospacedDigit())
                .foregroundStyle(.secondary)
            Toggle("", isOn: Binding(
                get: { pack.allEnabled },
                set: { manager.setPackEnabled(pack, enabled: $0) }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding()
    }

    // MARK: - Detail

    private var detailPane: some View {
        Group {
            if let skill = selectedSkill {
                SkillDetailView(skill: skill)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "puzzlepiece.extension")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("스킬을 선택하면 상세 정보가 표시됩니다")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Pack Row

struct PackRow: View {
    let pack: SkillPack

    var body: some View {
        HStack {
            Image(systemName: "shippingbox.fill")
                .foregroundStyle(.blue)
            VStack(alignment: .leading) {
                Text(pack.id)
                    .fontWeight(.medium)
                Text("\(pack.enabledCount)/\(pack.totalCount) 활성")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Skill Row

struct SkillRow: View {
    let skill: Skill
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(skill.isEnabled ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(skill.slashName)
                    .font(.body.monospaced())
                    .fontWeight(.medium)
                Text(skill.descriptionKo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { skill.isEnabled },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.switch)
            .labelsHidden()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

// MARK: - Skill Detail

struct SkillDetailView: View {
    @EnvironmentObject var manager: SkillManager
    let skill: Skill

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(skill.slashName)
                            .font(.largeTitle.monospaced().bold())
                        statusBadge
                    }
                    Text("Pack: \(skill.pack)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { skill.isEnabled },
                    set: { _ in manager.toggleSkill(skill) }
                ))
                .toggleStyle(.switch)
                .scaleEffect(1.2)
                .labelsHidden()
            }

            Divider()

            // Description
            VStack(alignment: .leading, spacing: 8) {
                Label("설명", systemImage: "text.alignleft")
                    .font(.headline)
                Text(skill.descriptionKo)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusBadge: some View {
        Text(skill.isEnabled ? "ON" : "OFF")
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(skill.isEnabled ? Color.green : Color.gray)
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
}
