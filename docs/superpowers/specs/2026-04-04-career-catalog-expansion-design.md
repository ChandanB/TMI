# Career Catalog Expansion Design

**Date:** 2026-04-04
**Status:** Draft
**Scope:** Expand career catalog from 32 to 520+ careers with redesigned taxonomy

## Overview

Overhaul the career catalog system from 8 categories / 32 careers to 20 categories / 520+ careers. Introduces subcategories for browsing, expands interest clusters from 8 to 14, and makes career pathways optional so new entries can be catalog-only.

Target audience: Mixed K-12 students.

## 1. Model Changes

### CareerPath

Two modifications to the existing `CareerPath` struct:

- `pathway: TMICareerPathway` becomes `pathway: TMICareerPathway?` — existing 32 careers keep their pathways, new catalog-only entries pass `nil`
- Add `subcategory: String` — display-only grouping within a category (e.g., "Life Sciences" under Science)

### New CareerCategory Enum

Replace hardcoded category strings with a `CareerCategory` enum for type safety. The enum provides:

- `rawValue: String` — machine identifier (e.g., `"science"`)
- `displayName: String` — human label (e.g., `"Science & Research"`)
- `icon: String` — SF Symbol name
- `color: String` — hex color for UI theming
- `growthPotential: String` — industry growth description
- `industryOutlook: String` — long-term outlook description

**Categories (20):**

| Enum Case | Display Name | Icon | Color |
|---|---|---|---|
| `agriculture` | Agriculture & Natural Resources | `leaf.fill` | `#27AE60` |
| `architecture` | Architecture & Design | `building.columns.fill` | `#8E44AD` |
| `artsEntertainment` | Arts & Entertainment | `paintpalette.fill` | `#E74C3C` |
| `business` | Business & Finance | `briefcase.fill` | `#2ECC71` |
| `communications` | Communications & Media | `megaphone.fill` | `#9B59B6` |
| `education` | Education & Training | `book.fill` | `#E67E22` |
| `engineering` | Engineering | `gearshape.2.fill` | `#2C3E50` |
| `environment` | Environment & Sustainability | `globe.americas.fill` | `#1ABC9C` |
| `government` | Government & Public Administration | `building.2.fill` | `#34495E` |
| `healthcare` | Healthcare & Medicine | `cross.case.fill` | `#16A085` |
| `hospitality` | Hospitality & Tourism | `fork.knife` | `#D35400` |
| `law` | Law & Criminal Justice | `scale.3d` | `#7F8C8D` |
| `manufacturing` | Manufacturing & Production | `hammer.fill` | `#95A5A6` |
| `military` | Military & Defense | `shield.fill` | `#2C3E50` |
| `science` | Science & Research | `atom` | `#2980B9` |
| `socialServices` | Social & Community Services | `hands.sparkles.fill` | `#1ABC9C` |
| `sports` | Sports & Recreation | `sportscourt.fill` | `#F39C12` |
| `technology` | Technology & Computing | `desktopcomputer` | `#3498DB` |
| `trades` | Skilled Trades | `wrench.and.screwdriver.fill` | `#E67E22` |
| `transportation` | Transportation & Logistics | `airplane` | `#5D6D7E` |

### No Changes To

- `CareerMatchResult` — works as-is
- `CareerMatchExplanation` — works as-is
- `StudentCareerState` — works as-is
- `Career` (Firestore model) — separate from static catalog

## 2. Data Architecture

Career data moves out of static extensions on `CareerPath` into organized category files.

### File Structure

```
TMI/Data/
  CareerCatalog.swift                    — aggregates all categories into single array
  Careers/
    AgricultureCareers.swift             (~25 careers)
    ArchitectureCareers.swift            (~20 careers)
    ArtsEntertainmentCareers.swift       (~35 careers)
    BusinessCareers.swift                (~35 careers)
    CommunicationsCareers.swift          (~25 careers)
    EducationCareers.swift               (~25 careers)
    EngineeringCareers.swift             (~30 careers)
    EnvironmentCareers.swift             (~20 careers)
    GovernmentCareers.swift              (~20 careers)
    HealthcareCareers.swift              (~40 careers)
    HospitalityCareers.swift             (~25 careers)
    LawCareers.swift                     (~25 careers)
    ManufacturingCareers.swift           (~20 careers)
    MilitaryCareers.swift                (~15 careers)
    ScienceCareers.swift                 (~30 careers)
    SocialServicesCareers.swift          (~25 careers)
    SportsCareers.swift                  (~25 careers)
    TechnologyCareers.swift              (~35 careers)
    TradesCareers.swift                  (~30 careers)
    TransportationCareers.swift          (~20 careers)
```

### CareerCatalog

```swift
struct CareerCatalog {
    static let allCareers: [CareerPath] =
        AgricultureCareers.all +
        ArchitectureCareers.all +
        ArtsEntertainmentCareers.all +
        // ... all 20 files
        TransportationCareers.all
}
```

### Category File Pattern

Each file follows this pattern:

```swift
enum AgricultureCareers {
    static let all: [CareerPath] = [
        CareerPath(
            title: "Farm Manager",
            category: "agriculture",
            subcategory: "Farming & Ranching",
            description: "Oversee daily operations of farms and ranches...",
            pathway: nil,
            requiredInterests: ["agriculture_nature", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 85000),
            educationLevel: .bachelors,
            icon: "leaf.fill",
            color: "#27AE60"
        ),
        // ... 24 more
    ]
}
```

### Backward Compatibility

`CareerDatabase.allCareerPaths` updated to reference `CareerCatalog.allCareers`. All existing consumers continue to work unchanged. The 32 existing careers with pathways are preserved in their respective new category files.

## 3. Interest Cluster Expansion

Expand from 8 to 14 clusters.

### Existing Clusters (kept)

- `audio_media`
- `technology`
- `creative_arts`
- `health_wellness`
- `sports_athletics`
- `business_entrepreneurship`
- `education`
- `social_services`

### New Clusters (6)

- `science_research` — science, research, laboratory, analytical careers
- `engineering_building` — engineering, manufacturing, architecture, trades, construction
- `law_government` — law, government, military, public policy, criminal justice
- `agriculture_nature` — agriculture, forestry, animal care, environmental work
- `hospitality_tourism` — hospitality, food service, travel, tourism, events
- `transportation_logistics` — transportation, logistics, supply chain, aviation

### Category-to-Cluster Mapping

| Career Category | Primary Cluster(s) |
|---|---|
| Agriculture | `agriculture_nature` |
| Architecture | `engineering_building`, `creative_arts` |
| Arts & Entertainment | `creative_arts`, `audio_media` |
| Business | `business_entrepreneurship` |
| Communications | `audio_media`, `creative_arts` |
| Education | `education` |
| Engineering | `engineering_building`, `technology` |
| Environment | `science_research`, `agriculture_nature` |
| Government | `law_government` |
| Healthcare | `health_wellness` |
| Hospitality | `hospitality_tourism` |
| Law | `law_government`, `social_services` |
| Manufacturing | `engineering_building` |
| Military | `law_government`, `sports_athletics` |
| Science | `science_research`, `technology` |
| Social Services | `social_services` |
| Sports | `sports_athletics` |
| Technology | `technology` |
| Trades | `engineering_building` |
| Transportation | `transportation_logistics` |

### Note on Interest Survey

The interest survey will eventually need updating to capture the 6 new clusters. This is a separate effort — for now, careers using new clusters will match less frequently until the survey is expanded.

## 4. Matching Engine Updates

### CareerMatchingService Changes

Minimal modifications:

1. **`determineGrowthPotential(for:)`** — delete switch statement, replace with `CareerCategory(rawValue: category)?.growthPotential`
2. **`industryOutlook(for:)`** — delete switch statement, replace with `CareerCategory(rawValue: category)?.industryOutlook`
3. **`suggestTMIModules(for:interests:)`** — expand switch to group new categories by affinity:
   - Engineering, Manufacturing, Trades, Architecture → same modules as Technology
   - Law, Government, Military → same modules as Social Services + Direct & Correct
   - Agriculture, Environment → Chase Your Space + Acknowledge Interests
   - Hospitality, Transportation → Chase Your Space + Acknowledge Interests
   - Science → same modules as Technology
   - Communications → same modules as Audio/Media

4. **`CareerDatabase.allCareerPaths`** — becomes `CareerCatalog.allCareers`

### No Changes To

- `matchCareers(from:dreamJob:)` — the core matching algorithm works on `requiredInterests` strings, which naturally extends
- `relevanceScore(for:)` on CareerPath — already generic
- `CareerMatchExplanation` scoring weights — remain 60/20/10/10

## 5. Career Data Per Entry

Each career entry contains:

| Field | Type | Example |
|---|---|---|
| `title` | String | "Marine Biologist" |
| `category` | String | "science" |
| `subcategory` | String | "Life Sciences" |
| `description` | String | 1-2 sentences, K-12 appropriate |
| `pathway` | TMICareerPathway? | `nil` for catalog-only |
| `requiredInterests` | [String] | `["science_research", "agriculture_nature"]` |
| `estimatedSalary` | SalaryRange? | `SalaryRange(min: 45000, max: 95000)` |
| `educationLevel` | EducationLevel | `.bachelors` |
| `icon` | String | SF Symbol name |
| `color` | String | Hex color (typically inherits from category) |

### Target Distribution (~520 total)

| Category | Subcategories | Count |
|---|---|---|
| Agriculture | Farming, Animal Care, Forestry, Horticulture | 25 |
| Architecture | Design, Urban Planning, Landscape, Interior | 20 |
| Arts & Entertainment | Visual Arts, Performing Arts, Music, Writing, Crafts | 35 |
| Business | Finance, Management, Marketing, HR, Real Estate | 35 |
| Communications | Journalism, PR, Broadcasting, Digital Media, Publishing | 25 |
| Education | Teaching, Administration, Special Ed, Training, Library | 25 |
| Engineering | Civil, Mechanical, Electrical, Chemical, Aerospace, Biomedical | 30 |
| Environment | Conservation, Sustainability, Climate, Renewable Energy | 20 |
| Government | Public Admin, Policy, Diplomacy, Intelligence, Urban Planning | 20 |
| Healthcare | Medical, Dental, Mental Health, Allied Health, Pharmacy | 40 |
| Hospitality | Food Service, Tourism, Events, Hotels, Recreation | 25 |
| Law | Legal Practice, Criminal Justice, Compliance, Mediation | 25 |
| Manufacturing | Production, Quality Control, Industrial, Textiles | 20 |
| Military | Service Branches, Defense Civilian, Intelligence | 15 |
| Science | Life Sciences, Physical Sciences, Earth Sciences, Research | 30 |
| Social Services | Counseling, Community Dev, Advocacy, Youth Services | 25 |
| Sports | Coaching, Management, Fitness, Recreation, Esports | 25 |
| Technology | Software, IT, Cybersecurity, AI/ML, Data, DevOps | 35 |
| Trades | Construction, Electrical, Plumbing, HVAC, Welding, Auto | 30 |
| Transportation | Aviation, Maritime, Rail, Trucking, Logistics, Warehousing | 20 |
| **Total** | | **~520** |

## 6. Migration Plan

1. Make `pathway` optional on `CareerPath`
2. Add `subcategory` field to `CareerPath`
3. Create `CareerCategory` enum
4. Create `TMI/Data/Careers/` directory and 20 category files
5. Create `CareerCatalog.swift` aggregator
6. Migrate existing 32 careers (with pathways) into their new category files
7. Add ~490 new catalog-only careers across all files
8. Update `CareerDatabase.allCareerPaths` to use `CareerCatalog.allCareers`
9. Update `CareerMatchingService` switch statements to use `CareerCategory` enum
10. Update any UI that assumes the old 8 categories (category filters, colors, icons)

## 7. Out of Scope

- Interest survey updates for new clusters (separate effort)
- Career pathway authoring for new entries (can be added incrementally)
- Firebase migration of existing career data
- Career Explorer UI redesign (existing views handle arrays of any size)
