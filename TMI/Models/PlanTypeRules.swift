//
//  PlanTypeRules.swift
//  TMI
//
//  Differentiated plan mechanics per TMI model
//

import Foundation

enum PlanArchetype: String, Codable, CaseIterable, Sendable {
    case focus = "Focus"
    case behavior = "Behavior"
    case social = "Social"
    case emotion = "Emotion"
    case identity = "Identity"
}

enum PlanPrimaryLever: String, Codable, CaseIterable, Sendable {
    case environment = "Environment"
    case thoughts = "Thoughts"
    case role = "Role"
    case routine = "Routine"
    case repair = "Repair"
}

enum PlanCadence: String, Codable, CaseIterable, Sendable {
    case dailyMicro = "Daily micro"
    case weeklyReview = "Weekly review"
    case incidentBased = "Incident-based"
    case mixed = "Mixed cadence"
}

enum PlanProofType: String, Codable, CaseIterable, Sendable {
    case checklist = "Checklist"
    case reflection = "Reflection"
    case incidentLog = "Incident log"
    case peerFeedback = "Peer feedback"
    case streaks = "Streaks"
    case tally = "Tally"
    case rating = "Rating"
}

enum PlanMechanic: String, Codable, CaseIterable, Sendable {
    case streaks = "Streaks"
    case incidentCapture = "Incident capture"
    case thoughtRewrite = "Thought rewrite"
    case spaceChecklist = "Space checklist"
    case repairCycle = "Repair cycle"
    case coachScript = "Coach script"
    case interestBinding = "Interest-to-task binding"
    case courageLadder = "Courage ladder"
    case ifThenRules = "If-Then rules"
}

enum PlanEvidenceType: String, Codable, CaseIterable, Sendable {
    case checklistCompletion = "Checklist completion"
    case reflectionEntry = "Reflection entry"
    case incidentCount = "Incident count"
    case peerFeedback = "Peer feedback"
    case streakLength = "Streak length"
    case teacherTally = "Teacher tally"
    case ratingTrend = "Rating trend"
    case questCompletion = "Quest completion"
}

struct PlanSuccessMetric: Codable, Hashable, Sendable {
    let title: String
    let target: String
}

struct PlanEscalationRule: Codable, Hashable, Sendable {
    let trigger: String
    let action: String
}

struct PlanSection: Codable, Hashable, Sendable {
    let title: String
    let icon: String
    let description: String
}

struct PlanRules: Codable, Hashable, Sendable {
    let archetype: PlanArchetype
    let primaryLever: PlanPrimaryLever
    let cadence: PlanCadence
    let proofTypes: [PlanProofType]
    let triggerConditions: [String]
    let uniqueFields: [String]
    let mechanics: [PlanMechanic]
    let sections: [PlanSection]
    let evidenceTypes: [PlanEvidenceType]
    let successMetrics: [PlanSuccessMetric]
    let escalationRules: [PlanEscalationRule]
}

extension TMIPlanModel {
    var planRules: PlanRules {
        switch self {
        case .chaseYourSpace:
            return PlanRules(
                archetype: .focus,
                primaryLever: .environment,
                cadence: .dailyMicro,
                proofTypes: [.checklist, .streaks],
                triggerConditions: [
                    "Student struggles to start work or maintain focus",
                    "Work readiness is inconsistent due to environment"
                ],
                uniqueFields: [
                    "My space type (desk/room/backpack/device)",
                    "5-item must-have setup",
                    "Clutter triggers + reset routine"
                ],
                mechanics: [.spaceChecklist, .streaks],
                sections: [
                    PlanSection(title: "Setup", icon: "square.grid.2x2", description: "Define the student’s workspace and must-have setup"),
                    PlanSection(title: "Daily Reset", icon: "checkmark.circle", description: "60-second readiness checklist"),
                    PlanSection(title: "Streaks", icon: "flame.fill", description: "Track consistency and recovery"),
                    PlanSection(title: "Notes", icon: "note.text", description: "Staff observations and adjustments")
                ],
                evidenceTypes: [.checklistCompletion, .streakLength, .ratingTrend],
                successMetrics: [
                    PlanSuccessMetric(title: "Ready-to-work score uptrend", target: "Increase over 4 weeks"),
                    PlanSuccessMetric(title: "Streak length", target: "7+ day streak")
                ],
                escalationRules: [
                    PlanEscalationRule(trigger: "No readiness improvement after 3 weeks", action: "Add Align Your Mind or counselor review")
                ]
            )
        case .acknowledgeInterests:
            return PlanRules(
                archetype: .identity,
                primaryLever: .routine,
                cadence: .mixed,
                proofTypes: [.reflection, .streaks],
                triggerConditions: [
                    "Low engagement despite adequate academic ability",
                    "Student reports boredom or lack of relevance"
                ],
                uniqueFields: [
                    "Top 3 interests",
                    "Interest-to-class mapping prompts",
                    "Reward schedule (intrinsic/extrinsic)"
                ],
                mechanics: [.interestBinding],
                sections: [
                    PlanSection(title: "Interest Map", icon: "map.fill", description: "Capture top interests and related themes"),
                    PlanSection(title: "Quests", icon: "flag.checkered", description: "Daily micro tasks tied to interests"),
                    PlanSection(title: "Engagement", icon: "sparkles", description: "Weekly planning and ratings"),
                    PlanSection(title: "Notes", icon: "note.text", description: "Teacher/counselor observations")
                ],
                evidenceTypes: [.questCompletion, .ratingTrend],
                successMetrics: [
                    PlanSuccessMetric(title: "Assignment completion", target: "+15% over baseline"),
                    PlanSuccessMetric(title: "Class participation", target: "3+ contributions/week")
                ],
                escalationRules: [
                    PlanEscalationRule(trigger: "Engagement ratings flat for 4 weeks", action: "Shift to Align Your Mind or Direct & Correct")
                ]
            )
        case .alignYourMind:
            return PlanRules(
                archetype: .emotion,
                primaryLever: .thoughts,
                cadence: .incidentBased,
                proofTypes: [.incidentLog, .reflection],
                triggerConditions: [
                    "Frequent negative thought patterns",
                    "Elevated stress during academic tasks"
                ],
                uniqueFields: [
                    "Trigger categories",
                    "Common negative thoughts",
                    "Replacement thought bank + coping actions"
                ],
                mechanics: [.thoughtRewrite],
                sections: [
                    PlanSection(title: "Triggers", icon: "bolt.fill", description: "Capture situations that activate stress"),
                    PlanSection(title: "Thought Logs", icon: "book.fill", description: "Log, reframe, replace"),
                    PlanSection(title: "Reframes", icon: "arrow.triangle.2.circlepath", description: "Build replacement thoughts"),
                    PlanSection(title: "Trends", icon: "chart.line.uptrend.xyaxis", description: "Track intensity over time")
                ],
                evidenceTypes: [.reflectionEntry, .ratingTrend, .incidentCount],
                successMetrics: [
                    PlanSuccessMetric(title: "Negative episode frequency", target: "-30% over 6 weeks"),
                    PlanSuccessMetric(title: "Stress rating", target: "Downtrend")
                ],
                escalationRules: [
                    PlanEscalationRule(trigger: "No change after 6 incidents logged", action: "Add counselor check-in + Direct & Correct")
                ]
            )
        case .directAndCorrect:
            return PlanRules(
                archetype: .behavior,
                primaryLever: .routine,
                cadence: .weeklyReview,
                proofTypes: [.tally, .incidentLog],
                triggerConditions: [
                    "Observable behavior impacting instruction",
                    "Repeated corrections without improvement"
                ],
                uniqueFields: [
                    "Target behavior definition (observable)",
                    "Replacement behavior",
                    "If-Then playbook",
                    "Reinforcement plan"
                ],
                mechanics: [.ifThenRules, .coachScript],
                sections: [
                    PlanSection(title: "Targets", icon: "scope", description: "Define behaviors and replacements"),
                    PlanSection(title: "Playbook", icon: "list.bullet.rectangle", description: "If-Then rules and scripts"),
                    PlanSection(title: "Check-ins", icon: "checkmark.seal", description: "Daily quick behavior check"),
                    PlanSection(title: "Weekly Review", icon: "calendar", description: "Trend analysis and adjustments")
                ],
                evidenceTypes: [.teacherTally, .incidentCount, .ratingTrend],
                successMetrics: [
                    PlanSuccessMetric(title: "Target behavior occurrences", target: "-50% over 4 weeks"),
                    PlanSuccessMetric(title: "Replacement behavior", target: "+3 instances/week")
                ],
                escalationRules: [
                    PlanEscalationRule(trigger: "Incidents unchanged after 4 weeks", action: "Escalate to Bully to Boss or counselor review")
                ]
            )
        case .bullyToBoss:
            return PlanRules(
                archetype: .social,
                primaryLever: .repair,
                cadence: .incidentBased,
                proofTypes: [.incidentLog, .peerFeedback],
                triggerConditions: [
                    "Harm to peers or repeated conflict incidents",
                    "Student displays leadership used negatively"
                ],
                uniqueFields: [
                    "Harm inventory (who impacted, what happened)",
                    "Accountability steps",
                    "Leadership role track"
                ],
                mechanics: [.repairCycle, .coachScript],
                sections: [
                    PlanSection(title: "Repair", icon: "arrow.uturn.backward.circle", description: "Restorative actions and accountability"),
                    PlanSection(title: "Leadership Tasks", icon: "person.badge.shield.checkmark", description: "Positive leadership practice"),
                    PlanSection(title: "Feedback", icon: "person.3", description: "Peer/staff input"),
                    PlanSection(title: "History", icon: "clock.arrow.circlepath", description: "Incident and repair history")
                ],
                evidenceTypes: [.incidentCount, .peerFeedback, .teacherTally],
                successMetrics: [
                    PlanSuccessMetric(title: "Incidents", target: "-60% over 6 weeks"),
                    PlanSuccessMetric(title: "Positive peer feedback", target: "Weekly positive feedback logged")
                ],
                escalationRules: [
                    PlanEscalationRule(trigger: "Repair steps incomplete after 2 incidents", action: "Admin review + intensive plan")
                ]
            )
        case .meekToProtector:
            return PlanRules(
                archetype: .identity,
                primaryLever: .role,
                cadence: .weeklyReview,
                proofTypes: [.streaks, .reflection],
                triggerConditions: [
                    "Avoidance of participation or self-advocacy",
                    "Reluctance to seek help"
                ],
                uniqueFields: [
                    "Fear list + situations",
                    "Assertive scripts",
                    "Safe ally network"
                ],
                mechanics: [.courageLadder],
                sections: [
                    PlanSection(title: "Courage Ladder", icon: "figure.climb", description: "Graduated challenges"),
                    PlanSection(title: "Scripts", icon: "text.bubble", description: "Practice assertive language"),
                    PlanSection(title: "Allies", icon: "person.2.fill", description: "Trusted staff/peers"),
                    PlanSection(title: "Progress", icon: "chart.bar", description: "Confidence trend")
                ],
                evidenceTypes: [.streakLength, .reflectionEntry, .ratingTrend],
                successMetrics: [
                    PlanSuccessMetric(title: "Self-advocacy actions", target: "+2/week"),
                    PlanSuccessMetric(title: "Avoidance behavior", target: "Downtrend")
                ],
                escalationRules: [
                    PlanEscalationRule(trigger: "No completed challenges after 3 weeks", action: "Reduce ladder difficulty + counselor session")
                ]
            )
        }
    }
}
