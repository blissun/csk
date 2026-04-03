import Foundation

struct Skill: Identifiable, Hashable {
    let id: String          // skill directory name
    let name: String        // display name (from SKILL.md frontmatter)
    let pack: String        // parent pack name
    let descriptionKo: String
    var isEnabled: Bool

    var slashName: String { "/\(id)" }
}

struct SkillPack: Identifiable {
    let id: String          // pack directory name
    let descriptionKo: String
    var skills: [Skill]

    var enabledCount: Int { skills.filter(\.isEnabled).count }
    var totalCount: Int { skills.count }
    var allEnabled: Bool { skills.allSatisfy(\.isEnabled) }
    var noneEnabled: Bool { skills.allSatisfy { !$0.isEnabled } }
}
