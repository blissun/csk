import Foundation
import Combine

final class SkillManager: ObservableObject {
    @Published var packs: [SkillPack] = []
    @Published var searchText: String = ""

    private let skillsDir: String
    private let disabledDir: String
    private let fm = FileManager.default

    init() {
        let home = fm.homeDirectoryForCurrentUser.path
        skillsDir = "\(home)/.claude/skills"
        disabledDir = "\(skillsDir)/.csk-disabled"
        try? fm.createDirectory(atPath: disabledDir, withIntermediateDirectories: true)
        reload()
    }

    // MARK: - Read state

    func reload() {
        var result: [SkillPack] = []
        guard let entries = try? fm.contentsOfDirectory(atPath: skillsDir) else { return }

        for entry in entries.sorted() {
            let fullPath = "\(skillsDir)/\(entry)"
            // Skip hidden dirs, symlinks, files
            if entry.hasPrefix(".") { continue }
            guard isDirectory(fullPath) && !isSymlink(fullPath) else { continue }

            // Check if this is a pack (has subdirs with SKILL.md)
            var skills: [Skill] = []
            guard let subEntries = try? fm.contentsOfDirectory(atPath: fullPath) else { continue }

            for sub in subEntries.sorted() {
                let subPath = "\(fullPath)/\(sub)"
                let skillMd = "\(subPath)/SKILL.md"
                if sub == "node_modules" { continue }
                guard isDirectory(subPath), fm.fileExists(atPath: skillMd) else { continue }

                let name = readSkillName(from: skillMd) ?? sub
                let enabled = isSymlink("\(skillsDir)/\(sub)")
                let desc = Self.helpKo[sub] ?? readDescription(from: skillMd)

                skills.append(Skill(
                    id: sub,
                    name: name,
                    pack: entry,
                    descriptionKo: desc,
                    isEnabled: enabled
                ))
            }

            if !skills.isEmpty {
                let packDesc = Self.packDescriptions[entry] ?? ""
                result.append(SkillPack(id: entry, descriptionKo: packDesc, skills: skills))
            }
        }

        packs = result
    }

    // MARK: - Toggle

    func toggleSkill(_ skill: Skill) {
        if skill.isEnabled {
            disableSkill(skill)
        } else {
            enableSkill(skill)
        }
        reload()
    }

    func enableSkill(_ skill: Skill) {
        let link = "\(skillsDir)/\(skill.id)"
        let target = "\(skill.pack)/\(skill.id)"
        try? fm.removeItem(atPath: link)
        try? fm.createSymbolicLink(atPath: link, withDestinationPath: target)
        try? fm.removeItem(atPath: "\(disabledDir)/\(skill.id)")
    }

    func disableSkill(_ skill: Skill) {
        let link = "\(skillsDir)/\(skill.id)"
        if isSymlink(link) {
            try? fm.removeItem(atPath: link)
        }
        fm.createFile(atPath: "\(disabledDir)/\(skill.id)", contents: nil)
    }

    func setPackEnabled(_ pack: SkillPack, enabled: Bool) {
        for skill in pack.skills {
            if enabled { enableSkill(skill) } else { disableSkill(skill) }
        }
        reload()
    }

    // MARK: - Filtered

    var filteredPacks: [SkillPack] {
        guard !searchText.isEmpty else { return packs }
        let q = searchText.lowercased()
        return packs.compactMap { pack in
            let filtered = pack.skills.filter {
                $0.id.lowercased().contains(q) ||
                $0.name.lowercased().contains(q) ||
                $0.descriptionKo.lowercased().contains(q)
            }
            guard !filtered.isEmpty else { return nil }
            return SkillPack(id: pack.id, descriptionKo: pack.descriptionKo, skills: filtered)
        }
    }

    // MARK: - File helpers

    private func isSymlink(_ path: String) -> Bool {
        guard let attrs = try? fm.attributesOfItem(atPath: path) else { return false }
        return attrs[.type] as? FileAttributeType == .typeSymbolicLink
    }

    private func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        // Follow symlinks for this check
        let resolvedPath: String
        if isSymlink(path) {
            resolvedPath = (try? fm.destinationOfSymbolicLink(atPath: path)) ?? path
            let base = (path as NSString).deletingLastPathComponent
            let full = resolvedPath.hasPrefix("/") ? resolvedPath : "\(base)/\(resolvedPath)"
            return fm.fileExists(atPath: full, isDirectory: &isDir) && isDir.boolValue
        }
        return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
    }

    private func readSkillName(from path: String) -> String? {
        guard let data = fm.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return nil }
        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("name:") {
                return line.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces)
            }
            if line == "---" && content.hasPrefix("---") && line != content.components(separatedBy: .newlines).first {
                break
            }
        }
        return nil
    }

    private func readDescription(from path: String) -> String {
        guard let data = fm.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else { return "" }
        var inDescription = false
        var desc: [String] = []
        for line in content.components(separatedBy: .newlines) {
            if line.hasPrefix("description:") {
                let inline = line.replacingOccurrences(of: "description:", with: "").trimmingCharacters(in: .whitespaces)
                if !inline.isEmpty && inline != "|" {
                    return inline
                }
                inDescription = true
                continue
            }
            if inDescription {
                if line.hasPrefix("  ") {
                    desc.append(line.trimmingCharacters(in: .whitespaces))
                } else {
                    break
                }
            }
        }
        return desc.joined(separator: " ")
    }

    // MARK: - Korean descriptions

    static let packDescriptions: [String: String] = [
        "gstack": "Garry's Stack — AI 엔지니어링 워크플로 (QA, 리뷰, 배포, 디자인, 브라우저)"
    ]

    static let helpKo: [String: String] = [
        "autoplan": "자동 리뷰 파이프라인. CEO/디자인/엔지니어링 리뷰를 순차 실행하고 판단 필요 시만 질문",
        "benchmark": "성능 회귀 감지. 페이지 로드, Core Web Vitals, 리소스 크기 기준선 비교",
        "browse": "헤드리스 브라우저. URL 탐색, 요소 조작, 스크린샷, 반응형/폼/업로드 테스트",
        "canary": "배포 후 카나리 모니터링. 콘솔 에러, 성능 저하, 페이지 실패 감지 및 알림",
        "careful": "위험 명령 안전장치. rm -rf, DROP TABLE, force-push 등 실행 전 경고",
        "codex": "OpenAI Codex CLI. 코드 리뷰(pass/fail), 챌린지(적대적 테스트), 컨설트(질의)",
        "connect-chrome": "실제 Chrome을 gstack으로 제어. 사이드 패널에서 실시간 활동 확인",
        "cso": "보안 감사. 시크릿/의존성/CI·CD/OWASP Top 10/STRIDE 위협 모델링",
        "design-consultation": "디자인 컨설팅. 제품 이해→경쟁 조사→디자인 시스템 제안→DESIGN.md 생성",
        "design-html": "AI 목업을 프로덕션 HTML/CSS로 변환. 30KB, 의존성 없음",
        "design-review": "디자이너 시점 QA. 시각적 불일치/간격/계층 문제 찾아 소스에서 직접 수정",
        "design-shotgun": "디자인 변형 다수 생성 → 비교 보드 → 피드백 수집 → 반복",
        "document-release": "배포 후 문서 갱신. diff 기반 README/ARCHITECTURE/CHANGELOG 자동 업데이트",
        "freeze": "디렉토리 잠금. 지정 경로 외부 편집 차단",
        "gstack-upgrade": "gstack 최신 버전 업그레이드",
        "guard": "최대 안전 모드. careful(위험 경고) + freeze(디렉토리 잠금)",
        "investigate": "체계적 디버깅. 조사→분석→가설→구현. 근본 원인 없이 수정 금지",
        "land-and-deploy": "PR 머지 → CI/배포 대기 → 프로덕션 카나리 헬스체크",
        "learn": "프로젝트 학습 관리. 세션 간 학습 내용 조회/검색/정리/내보내기",
        "office-hours": "YC 오피스 아워. 스타트업(수요 검증 6문항) / 빌더(디자인 씽킹)",
        "plan-ceo-review": "CEO 모드 플랜 리뷰. 10점짜리 제품 찾기, 전제 도전, 범위 확장",
        "plan-design-review": "디자이너 시점 플랜 리뷰. 각 차원 0-10 평가 후 10점 방법 제시",
        "plan-eng-review": "엔지니어링 매니저 플랜 리뷰. 아키텍처/데이터 흐름/엣지케이스/테스트",
        "qa": "웹앱 QA + 버그 수정. 테스트→발견→소스 수정→커밋→재검증 반복",
        "qa-only": "리포트 전용 QA. 버그 리포트만 생성, 코드 수정 없음",
        "retro": "주간 엔지니어링 회고. 커밋/작업 패턴/코드 품질 분석, 팀원별 기여도",
        "review": "PR 코드 리뷰. SQL 안전성, LLM 신뢰 경계, 조건부 사이드이펙트 분석",
        "setup-browser-cookies": "실제 브라우저 쿠키를 헤드리스 세션에 임포트. 인증 페이지 QA용",
        "setup-deploy": "배포 설정. Fly.io/Render/Vercel/Netlify/Heroku 등 플랫폼 자동 감지",
        "ship": "배포 워크플로. 테스트→리뷰→VERSION 범프→CHANGELOG→커밋→PR 생성",
        "unfreeze": "freeze 디렉토리 잠금 해제",
    ]
}
