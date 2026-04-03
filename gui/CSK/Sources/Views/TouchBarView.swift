import SwiftUI

struct TouchBarView: View {
    @EnvironmentObject var manager: SkillManager
    @Binding var selectedPack: String?

    var body: some View {
        let pack = currentPack
        if let pack = pack {
            ForEach(pack.skills.prefix(8)) { skill in
                Button(action: { manager.toggleSkill(skill) }) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(skill.isEnabled ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(skill.id)
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var currentPack: SkillPack? {
        guard let id = selectedPack else { return manager.packs.first }
        return manager.packs.first { $0.id == id }
    }
}
