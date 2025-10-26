//
//  PredefinedInterests.swift
//  TMI
//
//  Comprehensive catalog of predefined interests and hobbies for students
//

import Foundation
import CryptoKit

struct PredefinedInterestsData {

    // MARK: - Helper for Stable IDs

    /// Generate a stable, deterministic ID from an interest name
    private static func generateStableID(for name: String) -> String {
        // Use SHA256 to create a deterministic hash of the name
        let inputData = Data("predefined_interest_\(name)".utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined().prefix(24).lowercased()
    }

    // MARK: - Complete Interests Catalog

    static var allPredefinedInterests: [Interest] {
        // Combine all categories
        stemInterests +
        artsAndCreativeInterests +
        sportsAndPhysicalInterests +
        musicAndPerformingArtsInterests +
        literatureAndWritingInterests +
        scienceAndNatureInterests +
        socialAndLeadershipInterests +
        technologyAndGamingInterests +
        lifeskillsInterests +
        outdoorAndAdventureInterests +
        collectingAndHobbiesInterests +
        wellnessAndMindfulnessInterests
    }

    // MARK: - STEM & Technology (30+ interests)

    static var stemInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Robotics"),
                name: "Robotics",
                category: [.technology, .science],
                description: "Building and programming robots",
                academicRelevance: [.computerScience, .mathematics, .science],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 85,
                isFeatured: true,
                academicBenefits: "Improves logical thinking and engineering concepts",
                careerPathways: [.stem, .technology],
                skillsDeveloped: [.problemSolving, .criticalThinking, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Programming & Coding"),
                name: "Programming & Coding",
                category: [.technology],
                description: "Learning programming languages and app development",
                academicRelevance: [.computerScience, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 88,
                isFeatured: true,
                careerPathways: [.technology, .stem],
                skillsDeveloped: [.problemSolving, .criticalThinking, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "3D Printing & Design"),
                name: "3D Printing & Design",
                category: [.technology, .crafts],
                description: "Creating 3D models and printing physical objects",
                academicRelevance: [.computerScience, .art, .mathematics],
                interventionModels: [.chaseYourSpace],
                popularityScore: 75,
                careerPathways: [.technology, .stem, .creativeArts],
                skillsDeveloped: [.creativity, .problemSolving, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Web Development"),
                name: "Web Development",
                category: [.technology],
                description: "Building websites and web applications",
                academicRelevance: [.computerScience, .art],
                interventionModels: [.chaseYourSpace],
                popularityScore: 82,
                careerPathways: [.technology, .business],
                skillsDeveloped: [.creativity, .problemSolving, .communication]
            ),
            Interest(
                id: generateStableID(for: "Game Development"),
                name: "Game Development",
                category: [.technology, .gaming],
                description: "Creating video games and interactive experiences",
                academicRelevance: [.computerScience, .mathematics, .art],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 86,
                careerPathways: [.technology, .creativeArts],
                skillsDeveloped: [.creativity, .problemSolving, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Mobile App Development"),
                name: "Mobile App Development",
                category: [.technology],
                description: "Creating apps for smartphones and tablets",
                academicRelevance: [.computerScience],
                interventionModels: [.chaseYourSpace],
                popularityScore: 84,
                careerPathways: [.technology],
                skillsDeveloped: [.problemSolving, .creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Data Science & Analytics"),
                name: "Data Science & Analytics",
                category: [.technology, .mathematics],
                description: "Analyzing data to find patterns",
                academicRelevance: [.mathematics, .computerScience, .science],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 79,
                careerPathways: [.stem, .technology, .business],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Artificial Intelligence & Machine Learning"),
                name: "Artificial Intelligence & Machine Learning",
                category: [.technology, .science],
                description: "Teaching computers to learn and make decisions",
                academicRelevance: [.computerScience, .mathematics],
                interventionModels: [.chaseYourSpace],
                popularityScore: 80,
                isFeatured: true,
                careerPathways: [.technology, .stem],
                skillsDeveloped: [.criticalThinking, .problemSolving, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Cybersecurity"),
                name: "Cybersecurity",
                category: [.technology],
                description: "Protecting computer systems and networks",
                academicRelevance: [.computerScience, .mathematics],
                interventionModels: [.chaseYourSpace],
                popularityScore: 77,
                careerPathways: [.technology],
                skillsDeveloped: [.criticalThinking, .problemSolving, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Electronics & Circuit Design"),
                name: "Electronics & Circuit Design",
                category: [.technology, .science],
                description: "Building electronic devices and circuits",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 70,
                careerPathways: [.stem, .technology],
                skillsDeveloped: [.problemSolving, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Arduino & Microcontrollers"),
                name: "Arduino & Microcontrollers",
                category: [.technology],
                description: "Programming small computers for projects",
                academicRelevance: [.computerScience, .science],
                interventionModels: [.chaseYourSpace],
                popularityScore: 72,
                careerPathways: [.technology, .stem],
                skillsDeveloped: [.problemSolving, .creativity]
            ),
            Interest(
                id: generateStableID(for: "Drones & UAVs"),
                name: "Drones & UAVs",
                category: [.technology, .outdoors],
                description: "Flying and programming drones",
                academicRelevance: [.science, .mathematics, .computerScience],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 78,
                careerPathways: [.technology, .stem],
                skillsDeveloped: [.problemSolving, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Engineering & Maker Projects"),
                name: "Engineering & Maker Projects",
                category: [.crafts, .technology, .science],
                description: "Building and designing solutions",
                academicRelevance: [.science, .mathematics, .art],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 76,
                careerPathways: [.stem, .trades],
                skillsDeveloped: [.problemSolving, .creativity, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Math Puzzles & Competitions"),
                name: "Math Puzzles & Competitions",
                category: [.mathematics, .academics],
                description: "Solving challenging math problems",
                academicRelevance: [.mathematics],
                interventionModels: [.alignYourMind],
                popularityScore: 68,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Science Experiments"),
                name: "Science Experiments",
                category: [.science],
                description: "Conducting hands-on science experiments",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 74,
                careerPathways: [.stem, .healthcare],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Virtual Reality & AR Development"),
                name: "Virtual Reality & AR Development",
                category: [.technology],
                description: "Creating immersive VR and AR experiences",
                academicRelevance: [.computerScience, .art],
                interventionModels: [.chaseYourSpace],
                popularityScore: 81,
                careerPathways: [.technology, .creativeArts],
                skillsDeveloped: [.creativity, .problemSolving, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Blockchain & Cryptocurrency"),
                name: "Blockchain & Cryptocurrency",
                category: [.technology, .mathematics],
                description: "Understanding blockchain technology and digital currencies",
                academicRelevance: [.computerScience, .mathematics, .socialStudies],
                interventionModels: [.chaseYourSpace],
                popularityScore: 73,
                careerPathways: [.technology, .business],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Internet of Things (IoT)"),
                name: "Internet of Things (IoT)",
                category: [.technology, .science],
                description: "Connecting everyday devices to the internet",
                academicRelevance: [.computerScience, .science],
                interventionModels: [.chaseYourSpace],
                popularityScore: 71,
                careerPathways: [.technology, .stem],
                skillsDeveloped: [.problemSolving, .creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Cloud Computing"),
                name: "Cloud Computing",
                category: [.technology],
                description: "Learning cloud platforms and services",
                academicRelevance: [.computerScience],
                interventionModels: [.chaseYourSpace],
                popularityScore: 70,
                careerPathways: [.technology],
                skillsDeveloped: [.problemSolving, .adaptability]
            )
        ]
    }

    // MARK: - Arts & Creative (25+ interests)

    static var artsAndCreativeInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Drawing & Sketching"),
                name: "Drawing & Sketching",
                category: [.arts],
                description: "Creating art with pencils, pens, and markers",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 82,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Painting"),
                name: "Painting",
                category: [.arts],
                description: "Creating art with watercolors, acrylics, or oils",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 76,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Digital Art & Design"),
                name: "Digital Art & Design",
                category: [.arts, .technology],
                description: "Creating digital artwork and graphics",
                academicRelevance: [.art, .computerScience],
                interventionModels: [.acknowledgeInterests, .chaseYourSpace],
                popularityScore: 81,
                isFeatured: true,
                careerPathways: [.creativeArts, .technology],
                skillsDeveloped: [.creativity, .criticalThinking, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Animation"),
                name: "Animation",
                category: [.arts, .technology],
                description: "Creating moving images and cartoons",
                academicRelevance: [.art, .computerScience],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 80,
                careerPathways: [.creativeArts, .technology],
                skillsDeveloped: [.creativity, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Graphic Design"),
                name: "Graphic Design",
                category: [.arts, .technology],
                description: "Designing logos, posters, and visual communications",
                academicRelevance: [.art, .computerScience],
                interventionModels: [.chaseYourSpace],
                popularityScore: 78,
                careerPathways: [.creativeArts, .business],
                skillsDeveloped: [.creativity, .communication]
            ),
            Interest(
                id: generateStableID(for: "Photography"),
                name: "Photography",
                category: [.photography, .arts],
                description: "Capturing moments through the camera lens",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 83,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Videography & Film Making"),
                name: "Videography & Film Making",
                category: [.arts, .technology],
                description: "Creating videos and short films",
                academicRelevance: [.art, .english, .computerScience],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 84,
                careerPathways: [.creativeArts, .technology],
                skillsDeveloped: [.creativity, .teamwork, .communication]
            ),
            Interest(
                id: generateStableID(for: "Sculpture & 3D Art"),
                name: "Sculpture & 3D Art",
                category: [.arts, .crafts],
                description: "Creating three-dimensional artworks",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 65,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Pottery & Ceramics"),
                name: "Pottery & Ceramics",
                category: [.arts, .crafts],
                description: "Working with clay to create functional and decorative pieces",
                academicRelevance: [.art, .science],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 67,
                careerPathways: [.creativeArts, .trades],
                skillsDeveloped: [.creativity, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Fashion Design"),
                name: "Fashion Design",
                category: [.arts, .crafts],
                description: "Designing and creating clothing and accessories",
                academicRelevance: [.art, .mathematics],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 73,
                careerPathways: [.creativeArts, .business],
                skillsDeveloped: [.creativity, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Jewelry Making"),
                name: "Jewelry Making",
                category: [.crafts, .arts],
                description: "Creating wearable art and accessories",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 68,
                careerPathways: [.creativeArts, .business],
                skillsDeveloped: [.creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Calligraphy & Hand Lettering"),
                name: "Calligraphy & Hand Lettering",
                category: [.arts, .literature],
                description: "Creating beautiful handwritten art",
                academicRelevance: [.art, .english],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 64,
                skillsDeveloped: [.creativity, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Comic Book Art"),
                name: "Comic Book Art",
                category: [.arts, .literature],
                description: "Drawing comics and graphic novels",
                academicRelevance: [.art, .english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 77,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .communication]
            ),
            Interest(
                id: generateStableID(for: "Origami & Paper Crafts"),
                name: "Origami & Paper Crafts",
                category: [.crafts, .arts],
                description: "Folding paper into intricate designs",
                academicRelevance: [.art, .mathematics],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 66,
                skillsDeveloped: [.creativity, .resilience, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Street Art & Graffiti"),
                name: "Street Art & Graffiti",
                category: [.arts],
                description: "Urban art and mural painting",
                academicRelevance: [.art, .socialStudies],
                interventionModels: [.acknowledgeInterests, .fromBully2Boss],
                popularityScore: 74,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .communication]
            ),
            Interest(
                id: generateStableID(for: "Makeup & Special Effects"),
                name: "Makeup & Special Effects",
                category: [.arts, .crafts],
                description: "Creative makeup and theatrical effects",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 72,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Tattoo Art & Body Art"),
                name: "Tattoo Art & Body Art",
                category: [.arts],
                description: "Temporary and henna body art design",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 68,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity]
            ),
            Interest(
                id: generateStableID(for: "Cosplay & Costume Design"),
                name: "Cosplay & Costume Design",
                category: [.arts, .crafts, .entertainment],
                description: "Creating and wearing character costumes",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 75,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .problemSolving]
            )
        ]
    }

    // MARK: - Sports & Physical Activities (30+ interests)

    static var sportsAndPhysicalInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Basketball"),
                name: "Basketball",
                category: [.sports],
                description: "Playing and analyzing basketball",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 90,
                isFeatured: true,
                skillsDeveloped: [.teamwork, .leadership, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Soccer & Football"),
                name: "Soccer & Football",
                category: [.sports],
                description: "Playing soccer and football",
                academicRelevance: [.physicalEducation, .socialStudies],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 87,
                skillsDeveloped: [.teamwork, .leadership, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Baseball & Softball"),
                name: "Baseball & Softball",
                category: [.sports],
                description: "America's pastime sports",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 79,
                skillsDeveloped: [.teamwork, .resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Volleyball"),
                name: "Volleyball",
                category: [.sports],
                description: "Playing indoor and beach volleyball",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 75,
                skillsDeveloped: [.teamwork, .communication, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Tennis"),
                name: "Tennis",
                category: [.sports],
                description: "Playing singles and doubles tennis",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect],
                popularityScore: 72,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Track & Field"),
                name: "Track & Field",
                category: [.sports],
                description: "Running, jumping, and throwing events",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect],
                popularityScore: 74,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Swimming"),
                name: "Swimming",
                category: [.sports, .wellness],
                description: "Competitive and recreational swimming",
                academicRelevance: [.physicalEducation, .science],
                interventionModels: [.directAndCorrect, .alignYourMind],
                popularityScore: 78,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Martial Arts"),
                name: "Martial Arts",
                category: [.sports, .wellness],
                description: "Karate, Taekwondo, Judo, and other disciplines",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .fromBully2Boss, .fromMeek2Promising],
                popularityScore: 76,
                skillsDeveloped: [.resilience, .emotionalIntelligence, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Wrestling"),
                name: "Wrestling",
                category: [.sports],
                description: "Competitive wrestling",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 70,
                skillsDeveloped: [.resilience, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Gymnastics"),
                name: "Gymnastics",
                category: [.sports],
                description: "Artistic and rhythmic gymnastics",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .alignYourMind],
                popularityScore: 73,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Dance"),
                name: "Dance",
                category: [.arts, .sports],
                description: "Ballet, hip-hop, contemporary, and more",
                academicRelevance: [.physicalEducation, .music, .art],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 77,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .resilience, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Cheerleading"),
                name: "Cheerleading",
                category: [.sports],
                description: "Stunts, tumbling, and team spirit",
                academicRelevance: [.physicalEducation],
                interventionModels: [.fromBully2Boss, .fromMeek2Promising],
                popularityScore: 71,
                skillsDeveloped: [.teamwork, .leadership, .communication]
            ),
            Interest(
                id: generateStableID(for: "Golf"),
                name: "Golf",
                category: [.sports, .outdoors],
                description: "Playing golf recreationally and competitively",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect],
                popularityScore: 63,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Skateboarding"),
                name: "Skateboarding",
                category: [.sports, .outdoors],
                description: "Tricks and street skating",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .acknowledgeInterests],
                popularityScore: 75,
                skillsDeveloped: [.resilience, .creativity]
            ),
            Interest(
                id: generateStableID(for: "BMX & Cycling"),
                name: "BMX & Cycling",
                category: [.sports, .outdoors],
                description: "Bike riding, tricks, and racing",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect],
                popularityScore: 72,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Running & Jogging"),
                name: "Running & Jogging",
                category: [.sports, .wellness],
                description: "Distance and sprint running",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .alignYourMind],
                popularityScore: 76,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Yoga"),
                name: "Yoga",
                category: [.wellness, .sports],
                description: "Mind-body practice for flexibility and strength",
                academicRelevance: [.physicalEducation],
                interventionModels: [.alignYourMind, .directAndCorrect],
                popularityScore: 70,
                skillsDeveloped: [.emotionalIntelligence, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Weight Training & Fitness"),
                name: "Weight Training & Fitness",
                category: [.wellness, .sports],
                description: "Building strength and conditioning",
                academicRelevance: [.physicalEducation, .science],
                interventionModels: [.directAndCorrect, .chaseYourSpace],
                popularityScore: 74,
                careerPathways: [.healthcare],
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Parkour & Freerunning"),
                name: "Parkour & Freerunning",
                category: [.sports, .outdoors],
                description: "Urban acrobatics and obstacle navigation",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 73,
                skillsDeveloped: [.resilience, .creativity, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Ice Hockey"),
                name: "Ice Hockey",
                category: [.sports],
                description: "Fast-paced team sport on ice",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 71,
                skillsDeveloped: [.teamwork, .resilience, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Lacrosse"),
                name: "Lacrosse",
                category: [.sports],
                description: "Fast-paced stick and ball team sport",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect, .fromBully2Boss],
                popularityScore: 68,
                skillsDeveloped: [.teamwork, .resilience, .communication]
            ),
            Interest(
                id: generateStableID(for: "Archery"),
                name: "Archery",
                category: [.sports, .outdoors],
                description: "Precision bow and arrow sport",
                academicRelevance: [.physicalEducation, .mathematics],
                interventionModels: [.directAndCorrect, .alignYourMind],
                popularityScore: 66,
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Fencing"),
                name: "Fencing",
                category: [.sports],
                description: "Olympic sword fighting sport",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect],
                popularityScore: 64,
                skillsDeveloped: [.resilience, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Rowing & Crew"),
                name: "Rowing & Crew",
                category: [.sports, .outdoors],
                description: "Team water sport and fitness",
                academicRelevance: [.physicalEducation],
                interventionModels: [.directAndCorrect],
                popularityScore: 65,
                skillsDeveloped: [.teamwork, .resilience, .timeManagement]
            )
        ]
    }

    // MARK: - Music & Performing Arts (20+ interests)

    static var musicAndPerformingArtsInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Music Performance & Composition"),
                name: "Music Performance & Composition",
                category: [.music],
                description: "Playing instruments and creating music",
                academicRelevance: [.music, .mathematics],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 77,
                isFeatured: true,
                careerPathways: [.creativeArts, .education],
                skillsDeveloped: [.creativity, .timeManagement, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Piano"),
                name: "Piano",
                category: [.music],
                description: "Learning and performing on piano",
                academicRelevance: [.music, .mathematics],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 75,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Guitar"),
                name: "Guitar",
                category: [.music],
                description: "Acoustic and electric guitar playing",
                academicRelevance: [.music],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 82,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Drums & Percussion"),
                name: "Drums & Percussion",
                category: [.music],
                description: "Playing drums and percussion instruments",
                academicRelevance: [.music],
                interventionModels: [.acknowledgeInterests, .directAndCorrect],
                popularityScore: 73,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.resilience, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Singing & Vocal Performance"),
                name: "Singing & Vocal Performance",
                category: [.music, .arts],
                description: "Developing vocal skills and performance",
                academicRelevance: [.music, .english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 78,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.communication, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Orchestra & Band"),
                name: "Orchestra & Band",
                category: [.music],
                description: "Playing in ensembles",
                academicRelevance: [.music],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 69,
                careerPathways: [.creativeArts, .education],
                skillsDeveloped: [.teamwork, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Music Production & DJ"),
                name: "Music Production & DJ",
                category: [.music, .technology],
                description: "Creating and mixing music electronically",
                academicRelevance: [.music, .computerScience],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 80,
                careerPathways: [.creativeArts, .technology],
                skillsDeveloped: [.creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Theater & Drama"),
                name: "Theater & Drama",
                category: [.arts, .entertainment],
                description: "Acting and theater production",
                academicRelevance: [.english, .art, .music],
                interventionModels: [.fromMeek2Promising, .fromBully2Boss, .acknowledgeInterests],
                popularityScore: 68,
                isFeatured: true,
                careerPathways: [.creativeArts, .education],
                skillsDeveloped: [.communication, .teamwork, .emotionalIntelligence, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Musical Theater"),
                name: "Musical Theater",
                category: [.music, .arts, .entertainment],
                description: "Combining acting, singing, and dancing",
                academicRelevance: [.music, .english, .art],
                interventionModels: [.fromMeek2Promising, .acknowledgeInterests],
                popularityScore: 72,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.communication, .creativity, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Improv & Comedy"),
                name: "Improv & Comedy",
                category: [.arts, .entertainment],
                description: "Spontaneous performance and comedy",
                academicRelevance: [.english],
                interventionModels: [.fromMeek2Promising, .acknowledgeInterests],
                popularityScore: 67,
                skillsDeveloped: [.creativity, .adaptability, .communication]
            ),
            Interest(
                id: generateStableID(for: "Magic & Illusion"),
                name: "Magic & Illusion",
                category: [.entertainment, .arts],
                description: "Performing magic tricks and illusions",
                academicRelevance: [.mathematics],
                interventionModels: [.fromMeek2Promising, .acknowledgeInterests],
                popularityScore: 64,
                skillsDeveloped: [.creativity, .communication]
            ),
            Interest(
                id: generateStableID(for: "Beatboxing"),
                name: "Beatboxing",
                category: [.music, .entertainment],
                description: "Vocal percussion and sound creation",
                academicRelevance: [.music],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 70,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Rap & Hip-Hop"),
                name: "Rap & Hip-Hop",
                category: [.music, .literature],
                description: "Writing and performing rap music",
                academicRelevance: [.music, .english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 79,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Stand-Up Comedy"),
                name: "Stand-Up Comedy",
                category: [.entertainment, .arts],
                description: "Writing and performing comedy routines",
                academicRelevance: [.english],
                interventionModels: [.fromMeek2Promising, .acknowledgeInterests],
                popularityScore: 66,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.communication, .creativity, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Voice Acting & Dubbing"),
                name: "Voice Acting & Dubbing",
                category: [.arts, .entertainment],
                description: "Character voices and narration",
                academicRelevance: [.english],
                interventionModels: [.fromMeek2Promising, .acknowledgeInterests],
                popularityScore: 69,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .communication]
            )
        ]
    }

    // MARK: - Literature & Writing (15+ interests)

    static var literatureAndWritingInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Creative Writing"),
                name: "Creative Writing",
                category: [.literature, .arts],
                description: "Writing stories, poems, and creative works",
                academicRelevance: [.english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 72,
                isFeatured: true,
                careerPathways: [.creativeArts, .education],
                skillsDeveloped: [.creativity, .communication, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Poetry"),
                name: "Poetry",
                category: [.literature, .arts],
                description: "Writing and performing poetry",
                academicRelevance: [.english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 65,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Literature & Book Clubs"),
                name: "Literature & Book Clubs",
                category: [.literature, .academics],
                description: "Reading and discussing books",
                academicRelevance: [.english, .history],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 70,
                skillsDeveloped: [.criticalThinking, .communication, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Journalism & News Writing"),
                name: "Journalism & News Writing",
                category: [.literature, .communication],
                description: "Writing news articles and reporting",
                academicRelevance: [.english, .socialStudies],
                interventionModels: [.chaseYourSpace, .fromMeek2Promising],
                popularityScore: 66,
                careerPathways: [.business, .education],
                skillsDeveloped: [.communication, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Blogging & Content Creation"),
                name: "Blogging & Content Creation",
                category: [.literature, .technology],
                description: "Creating online content and blogs",
                academicRelevance: [.english, .computerScience],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 76,
                careerPathways: [.business, .technology],
                skillsDeveloped: [.communication, .creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Screenwriting"),
                name: "Screenwriting",
                category: [.literature, .arts],
                description: "Writing scripts for film and TV",
                academicRelevance: [.english, .art],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 69,
                careerPathways: [.creativeArts],
                skillsDeveloped: [.creativity, .communication]
            ),
            Interest(
                id: generateStableID(for: "Reading (Fiction & Non-Fiction)"),
                name: "Reading (Fiction & Non-Fiction)",
                category: [.literature],
                description: "Reading for enjoyment and learning",
                academicRelevance: [.english],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 79,
                skillsDeveloped: [.criticalThinking, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Fan Fiction Writing"),
                name: "Fan Fiction Writing",
                category: [.literature, .entertainment],
                description: "Writing stories based on favorite characters",
                academicRelevance: [.english],
                interventionModels: [.acknowledgeInterests, .fromMeek2Promising],
                popularityScore: 68,
                skillsDeveloped: [.creativity, .communication]
            )
        ]
    }

    // MARK: - Science & Nature (20+ interests)

    static var scienceAndNatureInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Environmental Science & Conservation"),
                name: "Environmental Science & Conservation",
                category: [.science, .outdoors, .socialCauses],
                description: "Protecting natural environments",
                academicRelevance: [.science, .socialStudies],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 75,
                isFeatured: true,
                careerPathways: [.stem, .publicService],
                skillsDeveloped: [.criticalThinking, .problemSolving, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Astronomy & Space Science"),
                name: "Astronomy & Space Science",
                category: [.science, .technology],
                description: "Studying space and the universe",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 73,
                careerPathways: [.stem, .technology],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Biology & Life Sciences"),
                name: "Biology & Life Sciences",
                category: [.science],
                description: "Studying living organisms",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace],
                popularityScore: 71,
                careerPathways: [.stem, .healthcare],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Chemistry"),
                name: "Chemistry",
                category: [.science],
                description: "Exploring chemical reactions and compounds",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 67,
                careerPathways: [.stem, .healthcare],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Physics & Mechanics"),
                name: "Physics & Mechanics",
                category: [.science, .mathematics],
                description: "Understanding how the world works",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace],
                popularityScore: 66,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Marine Biology & Oceanography"),
                name: "Marine Biology & Oceanography",
                category: [.science, .outdoors],
                description: "Studying ocean life and ecosystems",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace],
                popularityScore: 74,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Zoology & Animal Science"),
                name: "Zoology & Animal Science",
                category: [.science, .outdoors],
                description: "Studying animals and their behavior",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 79,
                careerPathways: [.stem, .healthcare],
                skillsDeveloped: [.criticalThinking, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Botany & Plant Science"),
                name: "Botany & Plant Science",
                category: [.science, .outdoors],
                description: "Studying plants and gardening",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 63,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Geology & Earth Science"),
                name: "Geology & Earth Science",
                category: [.science, .outdoors],
                description: "Studying rocks, minerals, and Earth processes",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace],
                popularityScore: 62,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Weather & Meteorology"),
                name: "Weather & Meteorology",
                category: [.science, .outdoors],
                description: "Studying weather patterns and forecasting",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace],
                popularityScore: 68,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Paleontology & Dinosaurs"),
                name: "Paleontology & Dinosaurs",
                category: [.science],
                description: "Studying fossils and prehistoric life",
                academicRelevance: [.science, .history],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 72,
                careerPathways: [.stem],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            )
        ]
    }

    // MARK: - Social & Leadership (15+ interests)

    static var socialAndLeadershipInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Student Government & Leadership"),
                name: "Student Government & Leadership",
                category: [.leadership, .socialCauses],
                description: "Leading student organizations",
                academicRelevance: [.socialStudies, .english],
                interventionModels: [.fromBully2Boss, .chaseYourSpace],
                popularityScore: 69,
                isFeatured: true,
                careerPathways: [.publicService, .business],
                skillsDeveloped: [.leadership, .communication, .problemSolving, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Debate & Public Speaking"),
                name: "Debate & Public Speaking",
                category: [.academics, .leadership, .communication],
                description: "Competitive debating and speeches",
                academicRelevance: [.english, .socialStudies],
                interventionModels: [.fromMeek2Promising, .alignYourMind],
                popularityScore: 66,
                careerPathways: [.business, .publicService],
                skillsDeveloped: [.communication, .criticalThinking, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Volunteering & Community Service"),
                name: "Volunteering & Community Service",
                category: [.socialCauses, .leadership],
                description: "Helping others and serving the community",
                academicRelevance: [.socialStudies],
                interventionModels: [.fromBully2Boss, .fromMeek2Promising],
                popularityScore: 74,
                careerPathways: [.publicService, .education],
                skillsDeveloped: [.leadership, .emotionalIntelligence, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Social Justice & Activism"),
                name: "Social Justice & Activism",
                category: [.socialCauses, .leadership],
                description: "Advocating for social change",
                academicRelevance: [.socialStudies, .history],
                interventionModels: [.fromBully2Boss, .chaseYourSpace],
                popularityScore: 67,
                careerPathways: [.publicService],
                skillsDeveloped: [.leadership, .communication, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Peer Mentoring & Tutoring"),
                name: "Peer Mentoring & Tutoring",
                category: [.leadership, .academics],
                description: "Helping other students learn",
                academicRelevance: AcademicSubject.allCases,
                interventionModels: [.fromBully2Boss, .fromMeek2Promising],
                popularityScore: 70,
                careerPathways: [.education],
                skillsDeveloped: [.leadership, .communication, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Event Planning & Organization"),
                name: "Event Planning & Organization",
                category: [.leadership, .social],
                description: "Planning and coordinating events",
                academicRelevance: [.mathematics, .english],
                interventionModels: [.fromBully2Boss, .chaseYourSpace],
                popularityScore: 71,
                careerPathways: [.business],
                skillsDeveloped: [.leadership, .timeManagement, .communication]
            ),
            Interest(
                id: generateStableID(for: "Model UN & Mock Trial"),
                name: "Model UN & Mock Trial",
                category: [.academics, .leadership],
                description: "Simulating government and legal proceedings",
                academicRelevance: [.socialStudies, .history, .english],
                interventionModels: [.fromMeek2Promising, .chaseYourSpace],
                popularityScore: 64,
                careerPathways: [.publicService, .business],
                skillsDeveloped: [.communication, .criticalThinking, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Podcast & Radio Production"),
                name: "Podcast & Radio Production",
                category: [.technology, .communication, .leadership],
                description: "Creating audio content and shows",
                academicRelevance: [.english, .computerScience],
                interventionModels: [.fromMeek2Promising, .chaseYourSpace],
                popularityScore: 72,
                careerPathways: [.technology, .business],
                skillsDeveloped: [.communication, .creativity, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Youth Advocacy & Organizing"),
                name: "Youth Advocacy & Organizing",
                category: [.socialCauses, .leadership],
                description: "Leading youth movements and campaigns",
                academicRelevance: [.socialStudies, .english],
                interventionModels: [.fromBully2Boss, .fromMeek2Promising],
                popularityScore: 65,
                careerPathways: [.publicService],
                skillsDeveloped: [.leadership, .communication, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Conflict Resolution & Mediation"),
                name: "Conflict Resolution & Mediation",
                category: [.leadership, .socialCauses],
                description: "Helping others resolve disagreements peacefully",
                academicRelevance: [.socialStudies],
                interventionModels: [.fromBully2Boss, .fromMeek2Promising],
                popularityScore: 61,
                careerPathways: [.publicService, .education],
                skillsDeveloped: [.emotionalIntelligence, .communication, .leadership]
            )
        ]
    }

    // MARK: - Technology & Gaming (15+ interests)

    static var technologyAndGamingInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Video Gaming"),
                name: "Video Gaming",
                category: [.gaming, .entertainment],
                description: "Playing video games competitively and casually",
                academicRelevance: [.computerScience],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 88,
                careerPathways: [.technology],
                skillsDeveloped: [.problemSolving, .adaptability, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Esports & Competitive Gaming"),
                name: "Esports & Competitive Gaming",
                category: [.gaming, .sports],
                description: "Professional and competitive gaming",
                academicRelevance: [.computerScience],
                interventionModels: [.chaseYourSpace, .fromBully2Boss],
                popularityScore: 83,
                careerPathways: [.technology, .business],
                skillsDeveloped: [.teamwork, .communication, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Streaming & Content Creation"),
                name: "Streaming & Content Creation",
                category: [.technology, .entertainment],
                description: "Creating gaming and entertainment content",
                academicRelevance: [.computerScience, .english],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 81,
                careerPathways: [.technology, .business],
                skillsDeveloped: [.communication, .creativity, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Board Games & Strategy Games"),
                name: "Board Games & Strategy Games",
                category: [.gaming, .social],
                description: "Playing tabletop and strategy games",
                academicRelevance: [.mathematics, .socialStudies],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 69,
                skillsDeveloped: [.criticalThinking, .problemSolving, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Tabletop RPGs & Dungeons & Dragons"),
                name: "Tabletop RPGs & Dungeons & Dragons",
                category: [.gaming, .social, .literature],
                description: "Role-playing games with friends",
                academicRelevance: [.english, .mathematics],
                interventionModels: [.fromMeek2Promising, .acknowledgeInterests],
                popularityScore: 71,
                skillsDeveloped: [.creativity, .teamwork, .communication]
            ),
            Interest(
                id: generateStableID(for: "Chess"),
                name: "Chess",
                category: [.gaming, .academics],
                description: "Strategic chess playing",
                academicRelevance: [.mathematics],
                interventionModels: [.alignYourMind],
                popularityScore: 65,
                skillsDeveloped: [.criticalThinking, .problemSolving, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Puzzle Solving"),
                name: "Puzzle Solving",
                category: [.gaming, .academics],
                description: "Crosswords, Sudoku, logic puzzles",
                academicRelevance: [.mathematics, .english],
                interventionModels: [.alignYourMind],
                popularityScore: 67,
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Retro Gaming & Game Collecting"),
                name: "Retro Gaming & Game Collecting",
                category: [.gaming, .collecting],
                description: "Playing and collecting classic video games",
                academicRelevance: [.history],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 70,
                skillsDeveloped: [.criticalThinking, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Speedrunning"),
                name: "Speedrunning",
                category: [.gaming, .sports],
                description: "Completing games as fast as possible",
                academicRelevance: [.mathematics],
                interventionModels: [.alignYourMind, .directAndCorrect],
                popularityScore: 68,
                skillsDeveloped: [.resilience, .problemSolving, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Trading Card Game Collecting"),
                name: "Trading Card Game Collecting",
                category: [.gaming, .collecting],
                description: "Collecting Pokémon, Yu-Gi-Oh!, Magic cards",
                academicRelevance: [.mathematics],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 76,
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Minecraft & Sandbox Games"),
                name: "Minecraft & Sandbox Games",
                category: [.gaming, .technology],
                description: "Building and creating in open-world games",
                academicRelevance: [.art, .mathematics],
                interventionModels: [.acknowledgeInterests, .chaseYourSpace],
                popularityScore: 89,
                isFeatured: true,
                careerPathways: [.technology, .creativeArts],
                skillsDeveloped: [.creativity, .problemSolving, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Roblox Development"),
                name: "Roblox Development",
                category: [.gaming, .technology],
                description: "Creating games and experiences in Roblox",
                academicRelevance: [.computerScience],
                interventionModels: [.chaseYourSpace],
                popularityScore: 85,
                careerPathways: [.technology],
                skillsDeveloped: [.creativity, .problemSolving, .adaptability]
            )
        ]
    }

    // MARK: - Life Skills (15+ interests)

    static var lifeskillsInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Cooking & Baking"),
                name: "Cooking & Baking",
                category: [.cooking, .crafts],
                description: "Preparing food and desserts",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 80,
                careerPathways: [.trades, .business],
                skillsDeveloped: [.creativity, .timeManagement, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Entrepreneurship & Business"),
                name: "Entrepreneurship & Business",
                category: [.academics, .leadership],
                description: "Starting businesses and learning economics",
                academicRelevance: [.mathematics, .socialStudies],
                interventionModels: [.chaseYourSpace, .fromBully2Boss],
                popularityScore: 74,
                careerPathways: [.business, .technology],
                skillsDeveloped: [.leadership, .problemSolving, .communication]
            ),
            Interest(
                id: generateStableID(for: "Foreign Languages & Cultures"),
                name: "Foreign Languages & Cultures",
                category: [.languages, .academics],
                description: "Learning languages and exploring cultures",
                academicRelevance: [.foreignLanguage, .socialStudies],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 68,
                careerPathways: [.education, .publicService, .business],
                skillsDeveloped: [.communication, .adaptability, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Personal Finance & Investing"),
                name: "Personal Finance & Investing",
                category: [.academics, .learning],
                description: "Managing money and investments",
                academicRelevance: [.mathematics, .socialStudies],
                interventionModels: [.chaseYourSpace],
                popularityScore: 66,
                careerPathways: [.business],
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Home Improvement & DIY"),
                name: "Home Improvement & DIY",
                category: [.crafts, .learning],
                description: "Fixing and building things at home",
                academicRelevance: [.mathematics, .science],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 67,
                careerPathways: [.trades],
                skillsDeveloped: [.problemSolving, .creativity]
            ),
            Interest(
                id: generateStableID(for: "Car Mechanics & Auto Repair"),
                name: "Car Mechanics & Auto Repair",
                category: [.technology, .crafts],
                description: "Working on vehicles",
                academicRelevance: [.science, .mathematics],
                interventionModels: [.chaseYourSpace, .alignYourMind],
                popularityScore: 69,
                careerPathways: [.trades, .stem],
                skillsDeveloped: [.problemSolving, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Woodworking & Carpentry"),
                name: "Woodworking & Carpentry",
                category: [.crafts, .arts],
                description: "Building with wood",
                academicRelevance: [.mathematics, .art],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 65,
                careerPathways: [.trades, .creativeArts],
                skillsDeveloped: [.creativity, .problemSolving, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Sewing & Textile Arts"),
                name: "Sewing & Textile Arts",
                category: [.crafts, .arts],
                description: "Creating with fabric and thread",
                academicRelevance: [.art, .mathematics],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 63,
                careerPathways: [.creativeArts, .business],
                skillsDeveloped: [.creativity, .resilience]
            )
        ]
    }

    // MARK: - Outdoor & Adventure (15+ interests)

    static var outdoorAndAdventureInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Hiking & Backpacking"),
                name: "Hiking & Backpacking",
                category: [.outdoors, .wellness],
                description: "Exploring trails and wilderness",
                academicRelevance: [.science, .physicalEducation],
                interventionModels: [.acknowledgeInterests, .directAndCorrect],
                popularityScore: 75,
                skillsDeveloped: [.resilience, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Camping"),
                name: "Camping",
                category: [.outdoors],
                description: "Outdoor camping and survival skills",
                academicRelevance: [.science, .physicalEducation],
                interventionModels: [.acknowledgeInterests, .directAndCorrect],
                popularityScore: 73,
                skillsDeveloped: [.resilience, .problemSolving, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Fishing"),
                name: "Fishing",
                category: [.outdoors],
                description: "Recreational and sport fishing",
                academicRelevance: [.science],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 70,
                skillsDeveloped: [.resilience, .emotionalIntelligence]
            ),
            Interest(
                id: generateStableID(for: "Rock Climbing"),
                name: "Rock Climbing",
                category: [.outdoors, .sports],
                description: "Indoor and outdoor climbing",
                academicRelevance: [.physicalEducation, .science],
                interventionModels: [.directAndCorrect, .alignYourMind],
                popularityScore: 71,
                skillsDeveloped: [.resilience, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Kayaking & Canoeing"),
                name: "Kayaking & Canoeing",
                category: [.outdoors, .sports],
                description: "Paddling and water sports",
                academicRelevance: [.physicalEducation, .science],
                interventionModels: [.directAndCorrect],
                popularityScore: 66,
                skillsDeveloped: [.resilience, .teamwork]
            ),
            Interest(
                id: generateStableID(for: "Surfing"),
                name: "Surfing",
                category: [.outdoors, .sports],
                description: "Riding ocean waves",
                academicRelevance: [.physicalEducation, .science],
                interventionModels: [.directAndCorrect],
                popularityScore: 72,
                skillsDeveloped: [.resilience, .adaptability]
            ),
            Interest(
                id: generateStableID(for: "Bird Watching"),
                name: "Bird Watching",
                category: [.outdoors, .science],
                description: "Observing and identifying birds",
                academicRelevance: [.science],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 58,
                skillsDeveloped: [.resilience, .criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Gardening"),
                name: "Gardening",
                category: [.outdoors, .science],
                description: "Growing plants and vegetables",
                academicRelevance: [.science],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 68,
                careerPathways: [.stem],
                skillsDeveloped: [.resilience, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Geocaching & Treasure Hunting"),
                name: "Geocaching & Treasure Hunting",
                category: [.outdoors, .gaming],
                description: "GPS-based treasure hunts",
                academicRelevance: [.mathematics, .science],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 64,
                skillsDeveloped: [.problemSolving, .teamwork]
            )
        ]
    }

    // MARK: - Collecting & Hobbies (10+ interests)

    static var collectingAndHobbiesInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Trading Card Games"),
                name: "Trading Card Games",
                category: [.collecting, .gaming],
                description: "Collecting and playing with trading cards",
                academicRelevance: [.mathematics],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 74,
                skillsDeveloped: [.criticalThinking, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "Coin & Stamp Collecting"),
                name: "Coin & Stamp Collecting",
                category: [.collecting],
                description: "Collecting coins, stamps, and currency",
                academicRelevance: [.history, .socialStudies],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 55,
                skillsDeveloped: [.criticalThinking, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Action Figure & Toy Collecting"),
                name: "Action Figure & Toy Collecting",
                category: [.collecting, .entertainment],
                description: "Collecting action figures and toys",
                academicRelevance: [.art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 68,
                skillsDeveloped: [.resilience]
            ),
            Interest(
                id: generateStableID(for: "Comic Book Collecting"),
                name: "Comic Book Collecting",
                category: [.collecting, .literature],
                description: "Collecting and reading comic books",
                academicRelevance: [.english, .art],
                interventionModels: [.acknowledgeInterests],
                popularityScore: 70,
                skillsDeveloped: [.criticalThinking]
            ),
            Interest(
                id: generateStableID(for: "Model Building"),
                name: "Model Building",
                category: [.crafts, .collecting],
                description: "Building scale models of cars, planes, etc.",
                academicRelevance: [.art, .mathematics],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 64,
                skillsDeveloped: [.resilience, .problemSolving]
            ),
            Interest(
                id: generateStableID(for: "LEGO & Construction Toys"),
                name: "LEGO & Construction Toys",
                category: [.crafts, .collecting],
                description: "Building with LEGO and similar toys",
                academicRelevance: [.mathematics, .art],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 76,
                skillsDeveloped: [.creativity, .problemSolving]
            )
        ]
    }

    // MARK: - Wellness & Mindfulness (10+ interests)

    static var wellnessAndMindfulnessInterests: [Interest] {
        [
            Interest(
                id: generateStableID(for: "Health & Fitness Science"),
                name: "Health & Fitness Science",
                category: [.wellness, .science],
                description: "Understanding health, nutrition, and fitness",
                academicRelevance: [.science, .physicalEducation],
                interventionModels: [.chaseYourSpace, .directAndCorrect],
                popularityScore: 71,
                careerPathways: [.healthcare, .stem],
                skillsDeveloped: [.problemSolving, .timeManagement, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Meditation & Mindfulness"),
                name: "Meditation & Mindfulness",
                category: [.wellness],
                description: "Practicing mindfulness and meditation",
                academicRelevance: [.physicalEducation],
                interventionModels: [.alignYourMind, .directAndCorrect, .fromMeek2Promising],
                popularityScore: 68,
                skillsDeveloped: [.emotionalIntelligence, .resilience]
            ),
            Interest(
                id: generateStableID(for: "Nutrition & Healthy Eating"),
                name: "Nutrition & Healthy Eating",
                category: [.wellness, .science, .cooking],
                description: "Learning about nutrition and healthy cooking",
                academicRelevance: [.science],
                interventionModels: [.chaseYourSpace, .acknowledgeInterests],
                popularityScore: 69,
                careerPathways: [.healthcare],
                skillsDeveloped: [.problemSolving, .timeManagement]
            ),
            Interest(
                id: generateStableID(for: "Mental Health Advocacy"),
                name: "Mental Health Advocacy",
                category: [.wellness, .socialCauses],
                description: "Promoting mental health awareness",
                academicRelevance: [.science, .socialStudies],
                interventionModels: [.fromMeek2Promising, .fromBully2Boss],
                popularityScore: 67,
                careerPathways: [.healthcare, .publicService],
                skillsDeveloped: [.emotionalIntelligence, .communication, .leadership]
            ),
            Interest(
                id: generateStableID(for: "Sleep & Recovery Science"),
                name: "Sleep & Recovery Science",
                category: [.wellness, .science],
                description: "Understanding sleep and recovery",
                academicRelevance: [.science],
                interventionModels: [.acknowledgeInterests, .alignYourMind],
                popularityScore: 62,
                careerPathways: [.healthcare],
                skillsDeveloped: [.criticalThinking]
            )
        ]
    }

    // MARK: - Helper Methods

    /// Get interests by category
    static func interests(for category: InterestCategory) -> [Interest] {
        allPredefinedInterests.filter { $0.category.contains(category) }
    }

    /// Get featured interests
    static var featuredInterests: [Interest] {
        allPredefinedInterests.filter { $0.isFeatured }
    }

    /// Get most popular interests
    static var popularInterests: [Interest] {
        allPredefinedInterests
            .sorted { ($0.popularityScore ?? 0) > ($1.popularityScore ?? 0) }
            .prefix(20)
            .map { $0 }
    }

    /// Get interests by intervention model
    static func interests(for model: InterventionModel) -> [Interest] {
        allPredefinedInterests.filter { $0.interventionModels.contains(model) }
    }

    /// Get interests by academic subject
    static func interests(for subject: AcademicSubject) -> [Interest] {
        allPredefinedInterests.filter { $0.academicRelevance.contains(subject) }
    }

    /// Get interests by career pathway
    static func interests(for pathway: CareerPathway) -> [Interest] {
        allPredefinedInterests.filter { $0.careerPathways?.contains(pathway) ?? false }
    }

    /// Search interests by name
    static func search(_ query: String) -> [Interest] {
        guard !query.isEmpty else { return allPredefinedInterests }
        let lowercased = query.lowercased()
        return allPredefinedInterests.filter {
            $0.name.lowercased().contains(lowercased) ||
            ($0.description?.lowercased().contains(lowercased) ?? false)
        }
    }
}
