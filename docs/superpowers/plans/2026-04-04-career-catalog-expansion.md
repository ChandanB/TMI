# Career Catalog Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the career catalog from 32 to 520+ careers across 20 categories with a redesigned taxonomy, new interest clusters, and catalog-only data entries.

**Architecture:** Add a `CareerCategory` enum for type-safe categories with display metadata. Make `CareerPath.pathway` optional so new careers can be catalog-only. Organize 520+ careers across 20 files in `TMI/Data/Careers/`, aggregated by a `CareerCatalog` struct. Expand interest clusters from 8 to 14. Update `CareerMatchingService` and `CareerService` to use the new enum instead of hardcoded switch statements.

**Tech Stack:** Swift 6, SwiftUI, existing CareerPath/Career models

---

### Task 1: Add `CareerCategory` Enum

**Files:**
- Create: `TMI/Models/Career/CareerCategory.swift`

- [ ] **Step 1: Create the CareerCategory enum file**

```swift
//
//  CareerCategory.swift
//  TMI
//
//  Type-safe career categories with display metadata
//

import Foundation

enum CareerCategory: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case agriculture = "agriculture"
    case architecture = "architecture"
    case artsEntertainment = "arts_entertainment"
    case business = "business"
    case communications = "communications"
    case education = "education"
    case engineering = "engineering"
    case environment = "environment"
    case government = "government"
    case healthcare = "healthcare"
    case hospitality = "hospitality"
    case law = "law"
    case manufacturing = "manufacturing"
    case military = "military"
    case science = "science"
    case socialServices = "social_services"
    case sports = "sports"
    case technology = "technology"
    case trades = "trades"
    case transportation = "transportation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .agriculture: return "Agriculture & Natural Resources"
        case .architecture: return "Architecture & Design"
        case .artsEntertainment: return "Arts & Entertainment"
        case .business: return "Business & Finance"
        case .communications: return "Communications & Media"
        case .education: return "Education & Training"
        case .engineering: return "Engineering"
        case .environment: return "Environment & Sustainability"
        case .government: return "Government & Public Administration"
        case .healthcare: return "Healthcare & Medicine"
        case .hospitality: return "Hospitality & Tourism"
        case .law: return "Law & Criminal Justice"
        case .manufacturing: return "Manufacturing & Production"
        case .military: return "Military & Defense"
        case .science: return "Science & Research"
        case .socialServices: return "Social & Community Services"
        case .sports: return "Sports & Recreation"
        case .technology: return "Technology & Computing"
        case .trades: return "Skilled Trades"
        case .transportation: return "Transportation & Logistics"
        }
    }

    var icon: String {
        switch self {
        case .agriculture: return "leaf.fill"
        case .architecture: return "building.columns.fill"
        case .artsEntertainment: return "paintpalette.fill"
        case .business: return "briefcase.fill"
        case .communications: return "megaphone.fill"
        case .education: return "book.fill"
        case .engineering: return "gearshape.2.fill"
        case .environment: return "globe.americas.fill"
        case .government: return "building.2.fill"
        case .healthcare: return "cross.case.fill"
        case .hospitality: return "fork.knife"
        case .law: return "scale.3d"
        case .manufacturing: return "hammer.fill"
        case .military: return "shield.fill"
        case .science: return "atom"
        case .socialServices: return "hands.sparkles.fill"
        case .sports: return "sportscourt.fill"
        case .technology: return "desktopcomputer"
        case .trades: return "wrench.and.screwdriver.fill"
        case .transportation: return "airplane"
        }
    }

    var color: String {
        switch self {
        case .agriculture: return "#27AE60"
        case .architecture: return "#8E44AD"
        case .artsEntertainment: return "#E74C3C"
        case .business: return "#2ECC71"
        case .communications: return "#9B59B6"
        case .education: return "#E67E22"
        case .engineering: return "#2C3E50"
        case .environment: return "#1ABC9C"
        case .government: return "#34495E"
        case .healthcare: return "#16A085"
        case .hospitality: return "#D35400"
        case .law: return "#7F8C8D"
        case .manufacturing: return "#95A5A6"
        case .military: return "#2C3E50"
        case .science: return "#2980B9"
        case .socialServices: return "#1ABC9C"
        case .sports: return "#F39C12"
        case .technology: return "#3498DB"
        case .trades: return "#E67E22"
        case .transportation: return "#5D6D7E"
        }
    }

    var growthPotential: String {
        switch self {
        case .technology: return "High - technology careers are growing rapidly with strong demand"
        case .healthcare: return "High - healthcare is an expanding field with aging population"
        case .business: return "Moderate to High - diverse opportunities across all industries"
        case .artsEntertainment: return "Moderate - creative fields can be competitive but rewarding"
        case .education: return "Stable - consistent demand for educators"
        case .socialServices: return "Moderate - growing awareness of mental health and social needs"
        case .sports: return "Moderate - competitive field with diverse industry opportunities"
        case .communications: return "High - digital media and content creation is booming"
        case .engineering: return "High - strong demand across civil, mechanical, and software"
        case .science: return "Moderate to High - research and innovation drive growth"
        case .law: return "Moderate - steady demand for legal professionals"
        case .government: return "Stable - consistent need for public servants"
        case .agriculture: return "Stable - essential industry with growing tech integration"
        case .architecture: return "Moderate - tied to construction and development cycles"
        case .environment: return "High - climate concerns driving rapid expansion"
        case .hospitality: return "Moderate - rebounding strongly with travel and events"
        case .manufacturing: return "Moderate - automation creating new skilled roles"
        case .military: return "Stable - consistent need for defense personnel"
        case .trades: return "High - skilled trades face significant worker shortages"
        case .transportation: return "Moderate to High - logistics and delivery demand growing"
        }
    }

    var industryOutlook: String {
        switch self {
        case .technology: return "Excellent long-term outlook with continuous innovation"
        case .healthcare: return "Strong outlook due to aging demographics and health focus"
        case .business: return "Stable with opportunities in emerging markets"
        case .artsEntertainment: return "Evolving with digital transformation and new platforms"
        case .education: return "Stable with ongoing need for qualified educators"
        case .socialServices: return "Growing demand for social support services"
        case .sports: return "Steady with opportunities in coaching, training, and analytics"
        case .communications: return "Rapidly growing with podcast and streaming boom"
        case .engineering: return "Strong demand driven by infrastructure and technology needs"
        case .science: return "Growing investment in research and development"
        case .law: return "Steady demand with evolution toward technology-assisted practice"
        case .government: return "Stable employment with good benefits and job security"
        case .agriculture: return "Evolving with precision agriculture and sustainability focus"
        case .architecture: return "Tied to economic cycles but growing with green building"
        case .environment: return "Rapidly expanding due to climate policy and corporate sustainability"
        case .hospitality: return "Strong rebound with experience-driven consumer spending"
        case .manufacturing: return "Transforming with automation, creating higher-skilled positions"
        case .military: return "Consistent with growing technology integration"
        case .trades: return "Excellent outlook due to retiring workforce and housing demand"
        case .transportation: return "Growing with e-commerce and supply chain complexity"
        }
    }

    var outlookAndGrowth: (String, Double) {
        switch self {
        case .technology: return ("Excellent long-term outlook with continuous innovation and strong demand.", 0.22)
        case .healthcare: return ("Strong outlook due to aging demographics and expanding healthcare needs.", 0.16)
        case .business: return ("Stable with opportunities in emerging markets and digital commerce.", 0.10)
        case .artsEntertainment: return ("Evolving with digital transformation and new content platforms.", 0.08)
        case .education: return ("Stable with ongoing need for qualified educators.", 0.05)
        case .socialServices: return ("Growing demand for social support and mental health services.", 0.12)
        case .sports: return ("Steady with opportunities in coaching, training, and sports analytics.", 0.07)
        case .communications: return ("Rapidly growing with the podcast and streaming content boom.", 0.18)
        case .engineering: return ("Strong demand driven by infrastructure and technology investment.", 0.14)
        case .science: return ("Growing investment in research across all disciplines.", 0.11)
        case .law: return ("Steady demand with increasing specialization opportunities.", 0.06)
        case .government: return ("Stable employment with consistent public sector demand.", 0.04)
        case .agriculture: return ("Essential industry evolving with technology and sustainability.", 0.05)
        case .architecture: return ("Moderate growth tied to construction and green building trends.", 0.07)
        case .environment: return ("Rapidly expanding due to climate awareness and policy.", 0.15)
        case .hospitality: return ("Strong rebound driven by experience-focused consumer spending.", 0.09)
        case .manufacturing: return ("Transforming with automation creating higher-skilled positions.", 0.06)
        case .military: return ("Consistent need with growing technology integration.", 0.03)
        case .trades: return ("Excellent outlook due to skilled worker shortages and housing demand.", 0.13)
        case .transportation: return ("Growing with e-commerce logistics and infrastructure investment.", 0.10)
        }
    }

    var baseSkills: [String] {
        switch self {
        case .technology: return ["Problem Solving", "Programming", "Critical Thinking", "Collaboration"]
        case .healthcare: return ["Patient Care", "Communication", "Empathy", "Medical Knowledge"]
        case .business: return ["Strategic Planning", "Leadership", "Communication", "Analytics"]
        case .artsEntertainment: return ["Creativity", "Visual Communication", "Attention to Detail", "Design Thinking"]
        case .education: return ["Communication", "Patience", "Curriculum Development", "Adaptability"]
        case .socialServices: return ["Empathy", "Active Listening", "Case Management", "Advocacy"]
        case .sports: return ["Physical Fitness", "Teamwork", "Coaching", "Performance Analysis"]
        case .communications: return ["Storytelling", "Audio Production", "Content Creation", "Audience Engagement"]
        case .engineering: return ["Mathematics", "Problem Solving", "Technical Design", "Project Management"]
        case .science: return ["Research", "Data Analysis", "Critical Thinking", "Scientific Writing"]
        case .law: return ["Legal Research", "Critical Thinking", "Negotiation", "Writing"]
        case .government: return ["Public Policy", "Communication", "Leadership", "Analysis"]
        case .agriculture: return ["Biology", "Land Management", "Problem Solving", "Physical Stamina"]
        case .architecture: return ["Design", "Spatial Reasoning", "CAD Software", "Project Management"]
        case .environment: return ["Environmental Science", "Data Analysis", "Research", "Policy Knowledge"]
        case .hospitality: return ["Customer Service", "Communication", "Organization", "Multitasking"]
        case .manufacturing: return ["Technical Skills", "Quality Control", "Safety Awareness", "Problem Solving"]
        case .military: return ["Discipline", "Leadership", "Physical Fitness", "Strategic Thinking"]
        case .trades: return ["Manual Dexterity", "Problem Solving", "Safety Knowledge", "Physical Stamina"]
        case .transportation: return ["Navigation", "Safety Awareness", "Time Management", "Communication"]
        }
    }

    /// Suggested TMI modules for careers in this category
    var suggestedTMIModules: [TMIPlanModel] {
        var modules: [TMIPlanModel] = [.chaseYourSpace, .acknowledgeInterests]
        switch self {
        case .technology, .engineering, .science, .manufacturing, .architecture:
            modules.append(.alignYourMind)
        case .business, .education, .government, .law:
            modules.append(.directAndCorrect)
        case .socialServices, .healthcare, .environment:
            modules.append(.meekToProtector)
        case .sports, .military, .trades:
            modules.append(.alignYourMind)
        case .artsEntertainment, .communications:
            modules.append(.alignYourMind)
        case .agriculture, .hospitality, .transportation:
            break // base modules only
        }
        if self == .business {
            modules.append(.bullyToBoss)
        }
        return modules
    }
}
```

- [ ] **Step 2: Verify file compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds (new file auto-discovered by Xcode filesystem sync)

- [ ] **Step 3: Commit**

```bash
git add TMI/Models/Career/CareerCategory.swift
git commit -m "feat: add CareerCategory enum with display metadata for 20 categories"
```

---

### Task 2: Make `CareerPath.pathway` Optional and Add `subcategory`

**Files:**
- Modify: `TMI/Models/Career/CareerModels.swift`

- [ ] **Step 1: Update CareerPath struct**

In `TMI/Models/Career/CareerModels.swift`, change the `pathway` property and add `subcategory`:

Replace the struct definition (lines 12-46):

```swift
struct CareerPath: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: String // Maps to CareerCategory rawValue
    let subcategory: String // Display grouping within category
    let description: String
    let pathway: TMICareerPathway? // nil for catalog-only entries
    let requiredInterests: [String] // Interest cluster names
    let estimatedSalary: SalaryRange?
    let educationLevel: EducationLevel
    let icon: String
    let color: String // Hex color

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        subcategory: String = "",
        description: String,
        pathway: TMICareerPathway? = nil,
        requiredInterests: [String],
        estimatedSalary: SalaryRange? = nil,
        educationLevel: EducationLevel = .varies,
        icon: String,
        color: String
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.subcategory = subcategory
        self.description = description
        self.pathway = pathway
        self.requiredInterests = requiredInterests
        self.estimatedSalary = estimatedSalary
        self.educationLevel = educationLevel
        self.icon = icon
        self.color = color
    }

    /// Calculate relevance score based on student's interest clusters
    func relevanceScore(for clusters: [InterestCluster]) -> Double {
        let clusterNames = Set(clusters.map { $0.name })
        let matchingInterests = requiredInterests.filter { clusterNames.contains($0) }

        guard !matchingInterests.isEmpty else { return 0.0 }

        let baseScore = Double(matchingInterests.count) / Double(requiredInterests.count)

        let weightBoost = clusters
            .filter { matchingInterests.contains($0.name) }
            .map { $0.weight }
            .reduce(0.0, +) / Double(matchingInterests.count)

        return (baseScore * 0.6) + (weightBoost * 0.4)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds. Existing 32 career definitions still compile because `subcategory` defaults to `""` and `pathway` is now optional with default `nil` (existing ones pass explicit pathway values).

- [ ] **Step 3: Commit**

```bash
git add TMI/Models/Career/CareerModels.swift
git commit -m "feat: make CareerPath.pathway optional, add subcategory field"
```

---

### Task 3: Add New Interest Clusters

**Files:**
- Modify: `TMI/Models/Survey/SurveyModels.swift` (lines 136-218)

- [ ] **Step 1: Add 6 new InterestCluster static properties**

In `TMI/Models/Survey/SurveyModels.swift`, add these new cluster definitions after the existing `.socialServices` cluster (after line 207) and before `allCategories`:

```swift
    static let scienceResearch = InterestCluster(
        name: "science_research",
        displayName: "Science & Research",
        weight: 0.0,
        relatedCareers: [],
        icon: "atom",
        color: "#2980B9"
    )

    static let engineeringBuilding = InterestCluster(
        name: "engineering_building",
        displayName: "Engineering & Building",
        weight: 0.0,
        relatedCareers: [],
        icon: "gearshape.2.fill",
        color: "#2C3E50"
    )

    static let lawGovernment = InterestCluster(
        name: "law_government",
        displayName: "Law & Government",
        weight: 0.0,
        relatedCareers: [],
        icon: "scale.3d",
        color: "#34495E"
    )

    static let agricultureNature = InterestCluster(
        name: "agriculture_nature",
        displayName: "Agriculture & Nature",
        weight: 0.0,
        relatedCareers: [],
        icon: "leaf.fill",
        color: "#27AE60"
    )

    static let hospitalityTourism = InterestCluster(
        name: "hospitality_tourism",
        displayName: "Hospitality & Tourism",
        weight: 0.0,
        relatedCareers: [],
        icon: "fork.knife",
        color: "#D35400"
    )

    static let transportationLogistics = InterestCluster(
        name: "transportation_logistics",
        displayName: "Transportation & Logistics",
        weight: 0.0,
        relatedCareers: [],
        icon: "airplane",
        color: "#5D6D7E"
    )
```

- [ ] **Step 2: Update `allCategories` array**

Replace the `allCategories` array (lines 209-218) with:

```swift
    static let allCategories: [InterestCluster] = [
        .audioMedia,
        .healthWellness,
        .technology,
        .creativeArts,
        .sportsAthletics,
        .businessEntrepreneurship,
        .education,
        .socialServices,
        .scienceResearch,
        .engineeringBuilding,
        .lawGovernment,
        .agricultureNature,
        .hospitalityTourism,
        .transportationLogistics
    ]
```

- [ ] **Step 3: Update `interestCategoryToClusterName` in CareerService**

In `TMI/Services/CareerService.swift`, update `interestCategoryToClusterName` (lines 529-543) to include the new clusters:

```swift
    private func interestCategoryToClusterName(_ category: String) -> String {
        switch category.lowercased() {
        case "technology": return "technology"
        case "science & discovery", "mathematics": return "science_research"
        case "arts & creativity", "photography", "making & building": return "creative_arts"
        case "sports & athletics": return "sports_athletics"
        case "music", "entertainment & media": return "audio_media"
        case "academics", "learning & education": return "education"
        case "leadership & service", "social causes", "social activities": return "social_services"
        case "health & wellness": return "health_wellness"
        case "outdoors & nature": return "agriculture_nature"
        case "communication", "languages & culture": return "social_services"
        case "engineering", "building", "construction": return "engineering_building"
        case "law", "government", "politics": return "law_government"
        case "cooking", "travel", "hospitality": return "hospitality_tourism"
        case "transportation", "vehicles", "logistics": return "transportation_logistics"
        default: return ""
        }
    }
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Models/Survey/SurveyModels.swift TMI/Services/CareerService.swift
git commit -m "feat: add 6 new interest clusters (science, engineering, law, agriculture, hospitality, transportation)"
```

---

### Task 4: Update `CareerService` to Use `CareerCategory` Enum

**Files:**
- Modify: `TMI/Services/CareerService.swift` (lines 57-135)

- [ ] **Step 1: Replace `fieldName(for:)` method**

Replace lines 57-69 with:

```swift
    private func fieldName(for category: String) -> String {
        CareerCategory(rawValue: category)?.displayName
            ?? category.replacingOccurrences(of: "_", with: " ").capitalized
    }
```

- [ ] **Step 2: Replace `outlookAndGrowth(for:)` method**

Replace lines 71-92 with:

```swift
    private func outlookAndGrowth(for category: String) -> (String, Double) {
        CareerCategory(rawValue: category)?.outlookAndGrowth
            ?? ("Outlook varies by specific role and location.", 0.08)
    }
```

- [ ] **Step 3: Replace `deriveSkills(from:)` method**

Replace lines 94-135 with:

```swift
    private func deriveSkills(from path: CareerPath) -> [String] {
        var skills = CareerCategory(rawValue: path.category)?.baseSkills
            ?? ["Communication", "Problem Solving", "Adaptability"]

        // Title-specific additional skills
        let title = path.title.lowercased()
        if title.contains("engineer") || title.contains("developer") {
            skills.append(contentsOf: ["Software Development", "System Design"])
        }
        if title.contains("analyst") || title.contains("data") {
            skills.append(contentsOf: ["Data Analysis", "Statistical Reasoning"])
        }
        if title.contains("designer") {
            skills.append(contentsOf: ["Adobe Creative Suite", "UI/UX Design"])
        }
        if title.contains("counselor") || title.contains("therapist") {
            skills.append(contentsOf: ["Counseling Techniques", "Mental Health Support"])
        }

        return skills
    }
```

- [ ] **Step 4: Replace `getFieldIcon(for:)` method**

Replace lines 271-289 with:

```swift
    func getFieldIcon(for field: String) -> String {
        // Try matching by rawValue first, then by displayName
        if let category = CareerCategory(rawValue: field.lowercased()) {
            return category.icon
        }
        for category in CareerCategory.allCases {
            if category.displayName.lowercased() == field.lowercased() {
                return category.icon
            }
        }
        return "star"
    }
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add TMI/Services/CareerService.swift
git commit -m "refactor: replace CareerService switch statements with CareerCategory enum"
```

---

### Task 5: Update `CareerMatchingService` to Use `CareerCategory` Enum

**Files:**
- Modify: `TMI/Services/CareerMatchingService.swift` (lines 222-373)

- [ ] **Step 1: Replace `determineGrowthPotential(for:)` method**

Replace lines 222-243 with:

```swift
    private func determineGrowthPotential(for category: String) -> String {
        CareerCategory(rawValue: category)?.growthPotential ?? "Varies by specialization"
    }
```

- [ ] **Step 2: Replace `industryOutlook(for:)` method**

Replace lines 246-267 with:

```swift
    private func industryOutlook(for category: String) -> String {
        CareerCategory(rawValue: category)?.industryOutlook ?? "Outlook varies by specific role and location"
    }
```

- [ ] **Step 3: Replace `suggestTMIModules(for:interests:)` method**

Replace lines 343-373 with:

```swift
    private func suggestTMIModules(for career: CareerPath, interests: [InterestCluster]) -> [TMIPlanModel] {
        CareerCategory(rawValue: career.category)?.suggestedTMIModules
            ?? [.chaseYourSpace, .acknowledgeInterests]
    }
```

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Services/CareerMatchingService.swift
git commit -m "refactor: replace CareerMatchingService switch statements with CareerCategory enum"
```

---

### Task 6: Create Career Data Files — Agriculture, Architecture, Arts & Entertainment

**Files:**
- Create: `TMI/Data/Careers/AgricultureCareers.swift`
- Create: `TMI/Data/Careers/ArchitectureCareers.swift`
- Create: `TMI/Data/Careers/ArtsEntertainmentCareers.swift`

- [ ] **Step 1: Create the Careers directory**

```bash
mkdir -p TMI/Data/Careers
```

- [ ] **Step 2: Create AgricultureCareers.swift**

Create `TMI/Data/Careers/AgricultureCareers.swift` with ~25 careers. Each career follows this pattern:

```swift
//
//  AgricultureCareers.swift
//  TMI
//
//  Agriculture & Natural Resources career catalog
//

import Foundation

enum AgricultureCareers {
    static let all: [CareerPath] = [
        // Farming & Ranching
        CareerPath(title: "Farm Manager", category: "agriculture", subcategory: "Farming & Ranching", description: "Oversee daily operations of farms including planting, harvesting, and managing workers.", pathway: nil, requiredInterests: ["agriculture_nature", "business_entrepreneurship"], estimatedSalary: SalaryRange(min: 40000, max: 85000), educationLevel: .bachelors, icon: "leaf.fill", color: "#27AE60"),
        CareerPath(title: "Rancher", category: "agriculture", subcategory: "Farming & Ranching", description: "Raise and manage livestock such as cattle, sheep, or horses for food and other products.", pathway: nil, requiredInterests: ["agriculture_nature"], estimatedSalary: SalaryRange(min: 35000, max: 80000), educationLevel: .highSchool, icon: "hare.fill", color: "#27AE60"),
        CareerPath(title: "Agricultural Engineer", category: "agriculture", subcategory: "Farming & Ranching", description: "Design agricultural equipment, structures, and processes to improve farming efficiency.", pathway: nil, requiredInterests: ["agriculture_nature", "engineering_building"], estimatedSalary: SalaryRange(min: 60000, max: 105000), educationLevel: .bachelors, icon: "gearshape.fill", color: "#27AE60"),
        CareerPath(title: "Crop Scientist", category: "agriculture", subcategory: "Farming & Ranching", description: "Research and develop methods to improve crop yields and quality.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 55000, max: 95000), educationLevel: .masters, icon: "leaf.arrow.circlepath", color: "#27AE60"),
        CareerPath(title: "Irrigation Specialist", category: "agriculture", subcategory: "Farming & Ranching", description: "Design and manage water systems to ensure efficient irrigation for crops.", pathway: nil, requiredInterests: ["agriculture_nature", "engineering_building"], estimatedSalary: SalaryRange(min: 45000, max: 80000), educationLevel: .bachelors, icon: "drop.fill", color: "#27AE60"),
        CareerPath(title: "Organic Farmer", category: "agriculture", subcategory: "Farming & Ranching", description: "Grow crops and raise animals using organic methods without synthetic chemicals.", pathway: nil, requiredInterests: ["agriculture_nature"], estimatedSalary: SalaryRange(min: 30000, max: 75000), educationLevel: .varies, icon: "leaf.fill", color: "#27AE60"),

        // Animal Care
        CareerPath(title: "Veterinarian", category: "agriculture", subcategory: "Animal Care", description: "Diagnose and treat injuries and diseases in animals to keep them healthy.", pathway: nil, requiredInterests: ["agriculture_nature", "health_wellness"], estimatedSalary: SalaryRange(min: 75000, max: 130000), educationLevel: .doctorate, icon: "pawprint.fill", color: "#27AE60"),
        CareerPath(title: "Veterinary Technician", category: "agriculture", subcategory: "Animal Care", description: "Assist veterinarians by performing clinical tasks and caring for animals.", pathway: nil, requiredInterests: ["agriculture_nature", "health_wellness"], estimatedSalary: SalaryRange(min: 30000, max: 50000), educationLevel: .vocational, icon: "pawprint.fill", color: "#27AE60"),
        CareerPath(title: "Animal Trainer", category: "agriculture", subcategory: "Animal Care", description: "Train animals for obedience, performance, riding, security, or assisting people with disabilities.", pathway: nil, requiredInterests: ["agriculture_nature"], estimatedSalary: SalaryRange(min: 28000, max: 60000), educationLevel: .highSchool, icon: "pawprint.fill", color: "#27AE60"),
        CareerPath(title: "Zoologist", category: "agriculture", subcategory: "Animal Care", description: "Study animals and their behavior, habitats, and ecosystems.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 50000, max: 85000), educationLevel: .bachelors, icon: "tortoise.fill", color: "#27AE60"),
        CareerPath(title: "Marine Biologist", category: "agriculture", subcategory: "Animal Care", description: "Study ocean ecosystems and marine organisms to understand and protect aquatic life.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 45000, max: 90000), educationLevel: .bachelors, icon: "fish.fill", color: "#27AE60"),
        CareerPath(title: "Wildlife Rehabilitator", category: "agriculture", subcategory: "Animal Care", description: "Care for injured, orphaned, or sick wild animals and prepare them for release.", pathway: nil, requiredInterests: ["agriculture_nature", "health_wellness"], estimatedSalary: SalaryRange(min: 25000, max: 45000), educationLevel: .certification, icon: "bird.fill", color: "#27AE60"),

        // Forestry & Conservation
        CareerPath(title: "Forester", category: "agriculture", subcategory: "Forestry & Conservation", description: "Manage forests for timber, conservation, recreation, and wildlife habitat.", pathway: nil, requiredInterests: ["agriculture_nature"], estimatedSalary: SalaryRange(min: 45000, max: 80000), educationLevel: .bachelors, icon: "tree.fill", color: "#27AE60"),
        CareerPath(title: "Park Ranger", category: "agriculture", subcategory: "Forestry & Conservation", description: "Protect and manage national and state parks while educating visitors.", pathway: nil, requiredInterests: ["agriculture_nature", "law_government"], estimatedSalary: SalaryRange(min: 35000, max: 65000), educationLevel: .bachelors, icon: "mountain.2.fill", color: "#27AE60"),
        CareerPath(title: "Conservation Scientist", category: "agriculture", subcategory: "Forestry & Conservation", description: "Manage natural resources and help landowners and governments protect the environment.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 50000, max: 85000), educationLevel: .bachelors, icon: "globe.americas.fill", color: "#27AE60"),
        CareerPath(title: "Arborist", category: "agriculture", subcategory: "Forestry & Conservation", description: "Care for trees and shrubs by pruning, fertilizing, and treating for disease.", pathway: nil, requiredInterests: ["agriculture_nature"], estimatedSalary: SalaryRange(min: 35000, max: 65000), educationLevel: .certification, icon: "tree.fill", color: "#27AE60"),
        CareerPath(title: "Fish and Game Warden", category: "agriculture", subcategory: "Forestry & Conservation", description: "Enforce hunting, fishing, and boating laws to protect wildlife and natural habitats.", pathway: nil, requiredInterests: ["agriculture_nature", "law_government"], estimatedSalary: SalaryRange(min: 40000, max: 75000), educationLevel: .bachelors, icon: "fish.fill", color: "#27AE60"),

        // Horticulture
        CareerPath(title: "Landscape Designer", category: "agriculture", subcategory: "Horticulture", description: "Plan and design outdoor spaces including gardens, parks, and residential landscapes.", pathway: nil, requiredInterests: ["agriculture_nature", "creative_arts"], estimatedSalary: SalaryRange(min: 40000, max: 80000), educationLevel: .bachelors, icon: "leaf.fill", color: "#27AE60"),
        CareerPath(title: "Horticulturist", category: "agriculture", subcategory: "Horticulture", description: "Grow and manage plants for food, medicine, and aesthetic purposes.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 40000, max: 75000), educationLevel: .bachelors, icon: "camera.macro", color: "#27AE60"),
        CareerPath(title: "Greenhouse Manager", category: "agriculture", subcategory: "Horticulture", description: "Manage greenhouse operations including plant propagation, climate control, and pest management.", pathway: nil, requiredInterests: ["agriculture_nature", "business_entrepreneurship"], estimatedSalary: SalaryRange(min: 35000, max: 65000), educationLevel: .vocational, icon: "humidity.fill", color: "#27AE60"),
        CareerPath(title: "Florist", category: "agriculture", subcategory: "Horticulture", description: "Design and arrange flowers and plants for events, gifts, and decorations.", pathway: nil, requiredInterests: ["agriculture_nature", "creative_arts"], estimatedSalary: SalaryRange(min: 25000, max: 50000), educationLevel: .highSchool, icon: "camera.macro", color: "#27AE60"),

        // Food Science
        CareerPath(title: "Food Scientist", category: "agriculture", subcategory: "Food Science", description: "Research and develop new food products and ensure food safety standards.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 55000, max: 95000), educationLevel: .bachelors, icon: "flask.fill", color: "#27AE60"),
        CareerPath(title: "Agricultural Inspector", category: "agriculture", subcategory: "Food Science", description: "Inspect farms, processing plants, and food products to ensure safety and compliance.", pathway: nil, requiredInterests: ["agriculture_nature", "law_government"], estimatedSalary: SalaryRange(min: 40000, max: 70000), educationLevel: .bachelors, icon: "checkmark.shield.fill", color: "#27AE60"),
        CareerPath(title: "Soil Scientist", category: "agriculture", subcategory: "Food Science", description: "Study soil composition and properties to advise on land use and agriculture.", pathway: nil, requiredInterests: ["agriculture_nature", "science_research"], estimatedSalary: SalaryRange(min: 50000, max: 85000), educationLevel: .bachelors, icon: "globe.americas.fill", color: "#27AE60"),
        CareerPath(title: "Aquaculture Farmer", category: "agriculture", subcategory: "Food Science", description: "Raise fish, shellfish, and aquatic plants in controlled environments for food.", pathway: nil, requiredInterests: ["agriculture_nature"], estimatedSalary: SalaryRange(min: 35000, max: 70000), educationLevel: .vocational, icon: "fish.fill", color: "#27AE60"),
    ]
}
```

- [ ] **Step 3: Create ArchitectureCareers.swift**

Create `TMI/Data/Careers/ArchitectureCareers.swift` with ~20 careers following the same pattern, organized into subcategories: "Building Design", "Urban Planning", "Landscape Architecture", "Interior Design". Include careers like: Architect, Residential Architect, Commercial Architect, Sustainable Building Designer, Urban Planner, City Manager, Regional Planner, Transportation Planner, Landscape Architect, Garden Designer, Interior Designer, Set Designer, Exhibition Designer, Lighting Designer, Building Inspector, Construction Manager, Drafting Technician, Historic Preservationist, Accessibility Consultant, Building Information Modeler.

- [ ] **Step 4: Create ArtsEntertainmentCareers.swift**

Create `TMI/Data/Careers/ArtsEntertainmentCareers.swift` with ~35 careers organized into subcategories: "Visual Arts", "Performing Arts", "Music", "Writing & Publishing", "Crafts & Design". Include the existing 4 creative arts careers (Graphic Designer, Photographer, Film Director, Animator — with their pathways preserved) plus new ones like: Sculptor, Painter, Muralist, Art Director, Art Therapist, Actor, Dancer, Choreographer, Stunt Performer, Theater Director, Stage Manager, Musician, Music Producer, Sound Designer, DJ, Music Therapist, Author, Screenwriter, Journalist, Technical Writer, Editor, Copywriter, Poet, Jeweler, Potter, Fashion Designer, Costume Designer, Textile Artist, Tattoo Artist, Illustrator, Comic Artist.

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add TMI/Data/Careers/AgricultureCareers.swift TMI/Data/Careers/ArchitectureCareers.swift TMI/Data/Careers/ArtsEntertainmentCareers.swift
git commit -m "feat: add career data for Agriculture (25), Architecture (20), Arts & Entertainment (35)"
```

---

### Task 7: Create Career Data Files — Business, Communications, Education

**Files:**
- Create: `TMI/Data/Careers/BusinessCareers.swift`
- Create: `TMI/Data/Careers/CommunicationsCareers.swift`
- Create: `TMI/Data/Careers/EducationCareers.swift`

- [ ] **Step 1: Create BusinessCareers.swift**

Create `TMI/Data/Careers/BusinessCareers.swift` with ~35 careers organized into subcategories: "Finance", "Management", "Marketing & Sales", "Human Resources", "Real Estate". Include the existing 4 business careers (Entrepreneur, Marketing Specialist, Financial Advisor, Business Analyst — with their pathways preserved) plus new ones like: Accountant, Auditor, Investment Banker, Insurance Agent, Stockbroker, Tax Consultant, Actuary, CEO, Operations Manager, Supply Chain Manager, Product Manager, Project Manager, Sales Manager, Advertising Manager, Market Research Analyst, Brand Manager, Public Relations Manager, Real Estate Agent, Property Manager, Real Estate Developer, HR Manager, Recruiter, Training Manager, Compensation Analyst, Management Consultant, Purchasing Manager, Event Planner, Office Manager, Franchise Owner, Import/Export Specialist, E-commerce Manager.

- [ ] **Step 2: Create CommunicationsCareers.swift**

Create `TMI/Data/Careers/CommunicationsCareers.swift` with ~25 careers organized into subcategories: "Journalism", "Public Relations", "Broadcasting", "Digital Media", "Publishing". Include the existing 4 audio/media careers (Podcaster, Radio Host, Audio Engineer, Content Creator — with their pathways preserved) plus new ones like: News Reporter, Investigative Journalist, Photojournalist, Sports Reporter, PR Specialist, Communications Director, Crisis Communications Manager, TV News Anchor, TV Producer, Broadcast Technician, Social Media Manager, SEO Specialist, Digital Marketing Manager, Video Editor, Web Content Manager, Book Publisher, Magazine Editor, Literary Agent, Speechwriter, Translator, Interpreter, Technical Communicator.

- [ ] **Step 3: Create EducationCareers.swift**

Create `TMI/Data/Careers/EducationCareers.swift` with ~25 careers organized into subcategories: "Teaching", "Administration", "Special Education", "Training & Development", "Library Science". Include the existing 4 education careers (Teacher, Tutor, Education Specialist, School Counselor — with their pathways preserved) plus new ones like: Elementary Teacher, Middle School Teacher, High School Teacher, College Professor, Preschool Teacher, ESL Teacher, Principal, Superintendent, Dean of Students, Academic Advisor, School Board Member, Special Education Teacher, Speech-Language Pathologist, Behavioral Therapist, Learning Disability Specialist, Corporate Trainer, Instructional Designer, E-Learning Developer, Librarian, Children's Librarian, Archivist, Museum Educator.

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Data/Careers/BusinessCareers.swift TMI/Data/Careers/CommunicationsCareers.swift TMI/Data/Careers/EducationCareers.swift
git commit -m "feat: add career data for Business (35), Communications (25), Education (25)"
```

---

### Task 8: Create Career Data Files — Engineering, Environment, Government

**Files:**
- Create: `TMI/Data/Careers/EngineeringCareers.swift`
- Create: `TMI/Data/Careers/EnvironmentCareers.swift`
- Create: `TMI/Data/Careers/GovernmentCareers.swift`

- [ ] **Step 1: Create EngineeringCareers.swift**

Create `TMI/Data/Careers/EngineeringCareers.swift` with ~30 careers organized into subcategories: "Civil & Structural", "Mechanical", "Electrical & Electronic", "Chemical & Biomedical", "Aerospace", "Computer Engineering". Include careers like: Civil Engineer, Structural Engineer, Transportation Engineer, Geotechnical Engineer, Mechanical Engineer, Robotics Engineer, HVAC Engineer, Automotive Engineer, Electrical Engineer, Electronics Engineer, Power Systems Engineer, Telecommunications Engineer, Chemical Engineer, Biomedical Engineer, Pharmaceutical Engineer, Materials Engineer, Aerospace Engineer, Avionics Engineer, Spacecraft Engineer, Computer Hardware Engineer, Network Engineer, Systems Engineer, Nuclear Engineer, Mining Engineer, Marine Engineer, Industrial Engineer, Quality Engineer, Safety Engineer, Manufacturing Engineer, Environmental Engineer.

- [ ] **Step 2: Create EnvironmentCareers.swift**

Create `TMI/Data/Careers/EnvironmentCareers.swift` with ~20 careers organized into subcategories: "Conservation", "Sustainability", "Climate Science", "Renewable Energy". Include careers like: Environmental Scientist, Ecologist, Climate Scientist, Meteorologist, Oceanographer, Hydrologist, Environmental Engineer, Sustainability Consultant, Carbon Analyst, ESG Analyst, Renewable Energy Technician, Solar Panel Installer, Wind Turbine Technician, Green Building Consultant, Waste Management Specialist, Recycling Coordinator, Environmental Compliance Officer, Water Quality Analyst, Air Quality Specialist, Environmental Educator.

- [ ] **Step 3: Create GovernmentCareers.swift**

Create `TMI/Data/Careers/GovernmentCareers.swift` with ~20 careers organized into subcategories: "Public Administration", "Policy & Diplomacy", "Intelligence & Security", "Public Service". Include careers like: City Manager, Public Administrator, Government Affairs Director, Lobbyist, Political Scientist, Diplomat, Foreign Service Officer, Policy Analyst, Legislative Aide, Intelligence Analyst, CIA Officer, FBI Agent, Customs Officer, TSA Agent, Mayor, City Council Member, Public Health Administrator, Emergency Management Director, Census Worker, Government Auditor.

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Data/Careers/EngineeringCareers.swift TMI/Data/Careers/EnvironmentCareers.swift TMI/Data/Careers/GovernmentCareers.swift
git commit -m "feat: add career data for Engineering (30), Environment (20), Government (20)"
```

---

### Task 9: Create Career Data Files — Healthcare, Hospitality, Law

**Files:**
- Create: `TMI/Data/Careers/HealthcareCareers.swift`
- Create: `TMI/Data/Careers/HospitalityCareers.swift`
- Create: `TMI/Data/Careers/LawCareers.swift`

- [ ] **Step 1: Create HealthcareCareers.swift**

Create `TMI/Data/Careers/HealthcareCareers.swift` with ~40 careers organized into subcategories: "Medical", "Dental", "Mental Health", "Allied Health", "Pharmacy & Research". Include the existing 4 health/wellness careers (Fitness Trainer, Nutritionist, Physical Therapist, Nurse — with their pathways preserved) plus new ones like: Physician, Surgeon, Pediatrician, Cardiologist, Dermatologist, Anesthesiologist, Radiologist, Emergency Room Doctor, Psychiatrist, Paramedic, EMT, Medical Assistant, Dentist, Dental Hygienist, Dental Assistant, Orthodontist, Psychologist, Clinical Psychologist, Marriage and Family Therapist, Substance Abuse Counselor, Art Therapist, Occupational Therapist, Respiratory Therapist, Speech-Language Pathologist, Audiologist, Optometrist, Chiropractor, Pharmacist, Pharmacy Technician, Medical Lab Technician, Epidemiologist, Public Health Educator, Health Information Technician, Surgical Technologist, Nurse Practitioner, Midwife.

- [ ] **Step 2: Create HospitalityCareers.swift**

Create `TMI/Data/Careers/HospitalityCareers.swift` with ~25 careers organized into subcategories: "Food Service", "Tourism & Travel", "Events & Entertainment", "Hotels & Lodging", "Recreation". Include careers like: Chef, Pastry Chef, Restaurant Manager, Sommelier, Food Critic, Caterer, Barista, Bartender, Travel Agent, Tour Guide, Cruise Director, Flight Attendant, Event Planner, Wedding Planner, Convention Manager, Meeting Coordinator, Hotel Manager, Concierge, Resort Director, Housekeeping Manager, Recreation Director, Amusement Park Manager, Spa Manager, Casino Manager, Campground Manager.

- [ ] **Step 3: Create LawCareers.swift**

Create `TMI/Data/Careers/LawCareers.swift` with ~25 careers organized into subcategories: "Legal Practice", "Criminal Justice", "Compliance & Regulation", "Dispute Resolution". Include careers like: Lawyer, Corporate Attorney, Criminal Defense Attorney, Public Defender, Prosecutor, Judge, Immigration Lawyer, Patent Attorney, Environmental Lawyer, Family Law Attorney, Police Officer, Detective, Forensic Scientist, Crime Scene Investigator, Corrections Officer, Probation Officer, Court Reporter, Paralegal, Legal Secretary, Compliance Officer, Regulatory Analyst, Privacy Officer, Mediator, Arbitrator, Legal Aid Worker.

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Data/Careers/HealthcareCareers.swift TMI/Data/Careers/HospitalityCareers.swift TMI/Data/Careers/LawCareers.swift
git commit -m "feat: add career data for Healthcare (40), Hospitality (25), Law (25)"
```

---

### Task 10: Create Career Data Files — Manufacturing, Military, Science

**Files:**
- Create: `TMI/Data/Careers/ManufacturingCareers.swift`
- Create: `TMI/Data/Careers/MilitaryCareers.swift`
- Create: `TMI/Data/Careers/ScienceCareers.swift`

- [ ] **Step 1: Create ManufacturingCareers.swift**

Create `TMI/Data/Careers/ManufacturingCareers.swift` with ~20 careers organized into subcategories: "Production", "Quality & Safety", "Industrial Design", "Textiles & Materials". Include careers like: Production Manager, Assembly Line Supervisor, CNC Machine Operator, Plant Manager, Manufacturing Technician, Process Engineer, Quality Control Inspector, Quality Assurance Manager, Safety Manager, Occupational Health Specialist, Industrial Designer, Product Designer, Packaging Designer, CAD Technician, Textile Designer, Materials Scientist, Plastics Technician, Metal Fabricator, Woodworker, 3D Printing Specialist.

- [ ] **Step 2: Create MilitaryCareers.swift**

Create `TMI/Data/Careers/MilitaryCareers.swift` with ~15 careers organized into subcategories: "Service Branches", "Defense Civilian", "Intelligence". Include careers like: Army Officer, Navy Officer, Air Force Pilot, Marine Corps Officer, Coast Guard Officer, Military Medic, Military Engineer, Cyber Operations Specialist, Defense Contractor, Military Analyst, Weapons Systems Analyst, Intelligence Officer, Cryptanalyst, Drone Operator, Military Police.

- [ ] **Step 3: Create ScienceCareers.swift**

Create `TMI/Data/Careers/ScienceCareers.swift` with ~30 careers organized into subcategories: "Life Sciences", "Physical Sciences", "Earth Sciences", "Research & Lab". Include careers like: Biologist, Microbiologist, Geneticist, Biochemist, Botanist, Neuroscientist, Physicist, Astrophysicist, Chemist, Materials Scientist, Nuclear Physicist, Geologist, Seismologist, Paleontologist, Volcanologist, Geographer, Astronomer, Atmospheric Scientist, Lab Technician, Research Scientist, Clinical Research Coordinator, Data Scientist, Biostatistician, Science Writer, Patent Examiner, Forensic Scientist, Pharmacologist, Toxicologist, Nanotechnologist, Quantum Computing Researcher.

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Data/Careers/ManufacturingCareers.swift TMI/Data/Careers/MilitaryCareers.swift TMI/Data/Careers/ScienceCareers.swift
git commit -m "feat: add career data for Manufacturing (20), Military (15), Science (30)"
```

---

### Task 11: Create Career Data Files — Social Services, Sports, Technology

**Files:**
- Create: `TMI/Data/Careers/SocialServicesCareers.swift`
- Create: `TMI/Data/Careers/SportsCareers.swift`
- Create: `TMI/Data/Careers/TechnologyCareers.swift`

- [ ] **Step 1: Create SocialServicesCareers.swift**

Create `TMI/Data/Careers/SocialServicesCareers.swift` with ~25 careers organized into subcategories: "Counseling", "Community Development", "Advocacy", "Youth Services". Include the existing 4 social services careers (Social Worker, Counselor, Community Organizer, Nonprofit Director — with their pathways preserved) plus new ones like: Clinical Social Worker, Child Welfare Worker, Crisis Counselor, Rehabilitation Counselor, Grief Counselor, Community Health Worker, Community Development Director, Housing Coordinator, Urban Planner, Homeless Services Coordinator, Human Rights Advocate, Disability Rights Specialist, Victim Advocate, Patient Advocate, Immigration Services Worker, Youth Counselor, Juvenile Probation Officer, After-School Program Director, Mentorship Coordinator, Youth Minister, Family Services Coordinator.

- [ ] **Step 2: Create SportsCareers.swift**

Create `TMI/Data/Careers/SportsCareers.swift` with ~25 careers organized into subcategories: "Coaching & Training", "Sports Management", "Fitness & Wellness", "Recreation", "Esports". Include the existing 4 sports careers (Coach, Athletic Trainer, Sports Analyst, PE Teacher — with their pathways preserved) plus new ones like: Head Coach, Assistant Coach, Strength and Conditioning Coach, Sports Psychologist, Sports Agent, Sports Marketing Manager, Team General Manager, Stadium Operations Manager, Sports Broadcaster, Sports Journalist, Personal Trainer, Group Fitness Instructor, Yoga Instructor, Pilates Instructor, Dance Instructor, Recreation Coordinator, Lifeguard, Outdoor Adventure Guide, Camp Director, Esports Coach, Esports Team Manager, Professional Gamer, Game Commentator.

- [ ] **Step 3: Create TechnologyCareers.swift**

Create `TMI/Data/Careers/TechnologyCareers.swift` with ~35 careers organized into subcategories: "Software Development", "IT & Infrastructure", "Cybersecurity", "AI & Data Science", "Product & Design", "DevOps & Cloud". Include the existing 4 technology careers (Game Developer, App Designer, Software Engineer, Data Analyst — with their pathways preserved) plus new ones like: Frontend Developer, Backend Developer, Full-Stack Developer, Mobile Developer, Embedded Systems Developer, Database Administrator, Systems Administrator, IT Support Specialist, Network Administrator, Help Desk Technician, IT Manager, Cybersecurity Analyst, Penetration Tester, Security Engineer, Chief Information Security Officer, AI Engineer, Machine Learning Engineer, NLP Specialist, Data Engineer, Data Architect, Business Intelligence Analyst, UX Designer, UX Researcher, Product Manager, Technical Product Manager, DevOps Engineer, Cloud Architect, Site Reliability Engineer, Blockchain Developer, Quantum Computing Engineer, Technical Writer.

- [ ] **Step 4: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add TMI/Data/Careers/SocialServicesCareers.swift TMI/Data/Careers/SportsCareers.swift TMI/Data/Careers/TechnologyCareers.swift
git commit -m "feat: add career data for Social Services (25), Sports (25), Technology (35)"
```

---

### Task 12: Create Career Data Files — Trades, Transportation

**Files:**
- Create: `TMI/Data/Careers/TradesCareers.swift`
- Create: `TMI/Data/Careers/TransportationCareers.swift`

- [ ] **Step 1: Create TradesCareers.swift**

Create `TMI/Data/Careers/TradesCareers.swift` with ~30 careers organized into subcategories: "Construction", "Electrical", "Plumbing & Pipefitting", "HVAC & Mechanical", "Automotive", "Other Trades". Include careers like: General Contractor, Carpenter, Framer, Roofer, Mason, Ironworker, Drywall Installer, Concrete Finisher, Electrician, Electrical Lineworker, Alarm Installer, Solar Panel Technician, Plumber, Pipefitter, Steamfitter, Sprinkler Fitter, HVAC Technician, Refrigeration Mechanic, Boiler Operator, Elevator Mechanic, Auto Mechanic, Diesel Mechanic, Auto Body Technician, Motorcycle Mechanic, Welder, Machinist, Locksmith, Glazier, Painter, Tile Setter.

- [ ] **Step 2: Create TransportationCareers.swift**

Create `TMI/Data/Careers/TransportationCareers.swift` with ~20 careers organized into subcategories: "Aviation", "Maritime", "Rail & Ground", "Logistics & Warehousing". Include careers like: Commercial Pilot, Airline Pilot, Air Traffic Controller, Aircraft Mechanic, Flight Dispatcher, Ship Captain, Marine Engineer, Port Manager, Merchant Mariner, Harbor Pilot, Train Engineer, Railroad Conductor, Bus Driver, Truck Driver, Delivery Driver, Logistics Manager, Warehouse Manager, Supply Chain Analyst, Freight Broker, Customs Broker.

- [ ] **Step 3: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add TMI/Data/Careers/TradesCareers.swift TMI/Data/Careers/TransportationCareers.swift
git commit -m "feat: add career data for Trades (30), Transportation (20)"
```

---

### Task 13: Create `CareerCatalog` Aggregator and Wire Up `CareerDatabase`

**Files:**
- Create: `TMI/Data/CareerCatalog.swift`
- Modify: `TMI/Services/CareerMatchingService.swift` (lines 391-441)

- [ ] **Step 1: Create CareerCatalog.swift**

```swift
//
//  CareerCatalog.swift
//  TMI
//
//  Aggregates all career category files into a single catalog
//

import Foundation

struct CareerCatalog {
    static let allCareers: [CareerPath] =
        AgricultureCareers.all +
        ArchitectureCareers.all +
        ArtsEntertainmentCareers.all +
        BusinessCareers.all +
        CommunicationsCareers.all +
        EducationCareers.all +
        EngineeringCareers.all +
        EnvironmentCareers.all +
        GovernmentCareers.all +
        HealthcareCareers.all +
        HospitalityCareers.all +
        LawCareers.all +
        ManufacturingCareers.all +
        MilitaryCareers.all +
        ScienceCareers.all +
        SocialServicesCareers.all +
        SportsCareers.all +
        TechnologyCareers.all +
        TradesCareers.all +
        TransportationCareers.all

    /// Get all careers grouped by category
    static var careersByCategory: [String: [CareerPath]] {
        Dictionary(grouping: allCareers, by: \.category)
    }

    /// Get all careers grouped by subcategory within a category
    static func careersGrouped(for category: String) -> [String: [CareerPath]] {
        let categoryCareers = allCareers.filter { $0.category == category }
        return Dictionary(grouping: categoryCareers, by: \.subcategory)
    }

    /// Get all unique subcategories for a given category
    static func subcategories(for category: String) -> [String] {
        Array(Set(allCareers.filter { $0.category == category }.map { $0.subcategory })).sorted()
    }

    /// Total career count
    static var count: Int { allCareers.count }
}
```

- [ ] **Step 2: Update `CareerDatabase.allCareerPaths`**

In `TMI/Services/CareerMatchingService.swift`, replace the `CareerDatabase` struct (lines 391-441) with:

```swift
struct CareerDatabase {
    static let allCareerPaths: [CareerPath] = CareerCatalog.allCareers
}
```

- [ ] **Step 3: Remove old static CareerPath extensions**

Delete the entire `extension CareerPath` block (lines 445-845 in `CareerMatchingService.swift`) that defines the 32 static career properties (`.podcaster`, `.radioHost`, etc.). These careers now live in their respective category files with their pathways preserved.

- [ ] **Step 4: Update `CareerService.allCareers` comment**

In `TMI/Services/CareerService.swift`, update the comment on line 21:

```swift
    /// All available careers from the static catalog (520+ careers across 20 categories)
```

- [ ] **Step 5: Verify it compiles**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add TMI/Data/CareerCatalog.swift TMI/Services/CareerMatchingService.swift TMI/Services/CareerService.swift
git commit -m "feat: wire up CareerCatalog aggregator, remove old static career definitions"
```

---

### Task 14: Final Verification and Career Count Check

**Files:**
- No new files

- [ ] **Step 1: Build the full project**

Run: `xcodebuild -project TMI.xcodeproj -scheme TMI -destination 'platform=macOS' build 2>&1 | tail -20`
Expected: Build succeeds with no errors

- [ ] **Step 2: Verify career count meets target**

Add a temporary print statement or check in code. The simplest approach: search for `CareerPath(title:` across all career files and count:

```bash
grep -c "CareerPath(title:" TMI/Data/Careers/*.swift | tail -25
```

Expected: Total across all files should be 500+

- [ ] **Step 3: Verify no duplicate career titles**

```bash
grep "CareerPath(title:" TMI/Data/Careers/*.swift | sed 's/.*title: "\(.*\)".*/\1/' | sort | uniq -d
```

Expected: No duplicates printed

- [ ] **Step 4: Verify all 20 categories are represented**

```bash
grep "category:" TMI/Data/Careers/*.swift | sed 's/.*category: "\(.*\)".*/\1/' | sort -u
```

Expected: 20 unique category strings matching `CareerCategory` rawValues

- [ ] **Step 5: Commit final state**

```bash
git add -A
git commit -m "feat: complete career catalog expansion to 520+ careers across 20 categories"
```
