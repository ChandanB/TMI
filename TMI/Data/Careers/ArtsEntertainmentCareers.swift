//
//  ArtsEntertainmentCareers.swift
//  TMI
//
//  Career data for the Arts & Entertainment category
//

import Foundation

enum ArtsEntertainmentCareers {
    static let all: [CareerPath] = [

        // MARK: - Visual Arts

        CareerPath(
            title: "Painter",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Create original artwork using paint, canvas, and color to express ideas and emotions. Painters work as fine artists, illustrators, or commercial artists.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 28000, max: 80000),
            educationLevel: .varies,
            icon: "paintpalette.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Sculptor",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Shape materials like clay, stone, metal, or wood into three-dimensional works of art. Sculptors exhibit in galleries, public spaces, and museums.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 28000, max: 75000),
            educationLevel: .bachelors,
            icon: "cube.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Muralist",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Paint large-scale artwork on walls and public surfaces to beautify communities and share stories. Muralists work on commission for cities, businesses, and organizations.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 30000, max: 85000),
            educationLevel: .varies,
            icon: "paintbrush.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Art Director",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Lead the visual style and creative direction for advertising, film, magazines, and other media projects. Art directors oversee teams of designers and artists.",
            pathway: nil,
            requiredInterests: ["creative_arts", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 65000, max: 140000),
            educationLevel: .bachelors,
            icon: "eye.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Illustrator",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Create images for books, magazines, websites, and advertising using traditional or digital tools. Illustrators bring ideas and stories to life visually.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 35000, max: 90000),
            educationLevel: .bachelors,
            icon: "pencil.tip",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Comic Artist",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Draw comic books, graphic novels, and webcomics by combining sequential art and storytelling. Comic artists work independently or for major publishers.",
            pathway: nil,
            requiredInterests: ["creative_arts", "audio_media"],
            estimatedSalary: SalaryRange(min: 28000, max: 85000),
            educationLevel: .varies,
            icon: "pencil.and.outline",
            color: "#E74C3C"
        ),

        // MARK: - Performing Arts

        CareerPath(
            title: "Actor",
            category: "arts_entertainment",
            subcategory: "Performing Arts",
            description: "Portray characters in film, television, theater, or commercials through voice, movement, and expression. Actors audition for roles and rehearse scripts.",
            pathway: nil,
            requiredInterests: ["creative_arts", "audio_media"],
            estimatedSalary: SalaryRange(min: 25000, max: 500000),
            educationLevel: .varies,
            icon: "theatermasks.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Dancer",
            category: "arts_entertainment",
            subcategory: "Performing Arts",
            description: "Perform in ballets, musicals, music videos, or contemporary shows using movement and rhythm to tell stories. Dancers train rigorously to master their craft.",
            pathway: nil,
            requiredInterests: ["creative_arts", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 25000, max: 75000),
            educationLevel: .varies,
            icon: "figure.dance",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Choreographer",
            category: "arts_entertainment",
            subcategory: "Performing Arts",
            description: "Design and direct dance routines for stage shows, films, music videos, and live performances. Choreographers combine artistic vision with technical knowledge of movement.",
            pathway: nil,
            requiredInterests: ["creative_arts", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 35000, max: 90000),
            educationLevel: .varies,
            icon: "figure.step.training",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Stunt Performer",
            category: "arts_entertainment",
            subcategory: "Performing Arts",
            description: "Execute dangerous or physically demanding scenes in film and television safely. Stunt performers train in martial arts, acrobatics, driving, and other specialized skills.",
            pathway: nil,
            requiredInterests: ["creative_arts", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 40000, max: 120000),
            educationLevel: .varies,
            icon: "flame.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Theater Director",
            category: "arts_entertainment",
            subcategory: "Performing Arts",
            description: "Guide the artistic vision of a stage production by directing actors, designers, and crew. Theater directors interpret scripts and bring performances to life.",
            pathway: nil,
            requiredInterests: ["creative_arts", "education"],
            estimatedSalary: SalaryRange(min: 35000, max: 100000),
            educationLevel: .bachelors,
            icon: "theatermasks",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Stage Manager",
            category: "arts_entertainment",
            subcategory: "Performing Arts",
            description: "Coordinate all elements of a theatrical production including schedules, cues, and communication between cast and crew. Stage managers ensure every performance runs smoothly.",
            pathway: nil,
            requiredInterests: ["creative_arts", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 35000, max: 85000),
            educationLevel: .bachelors,
            icon: "list.clipboard.fill",
            color: "#E74C3C"
        ),

        // MARK: - Music

        CareerPath(
            title: "Musician",
            category: "arts_entertainment",
            subcategory: "Music",
            description: "Perform, record, and create music as a vocalist or instrumentalist across genres. Musicians work in bands, orchestras, session recording, and live performance.",
            pathway: nil,
            requiredInterests: ["creative_arts", "audio_media"],
            estimatedSalary: SalaryRange(min: 25000, max: 300000),
            educationLevel: .varies,
            icon: "music.note",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Music Producer",
            category: "arts_entertainment",
            subcategory: "Music",
            description: "Oversee and guide the recording process to shape the sound of an album or song. Music producers work with artists in the studio to create polished final recordings.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 35000, max: 200000),
            educationLevel: .varies,
            icon: "slider.horizontal.3",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Sound Designer",
            category: "arts_entertainment",
            subcategory: "Music",
            description: "Create and manipulate audio effects for films, video games, theater, and other media. Sound designers craft the sonic world that audiences hear.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts", "technology"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .vocational,
            icon: "waveform.path",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "DJ",
            category: "arts_entertainment",
            subcategory: "Music",
            description: "Mix and play recorded music at clubs, events, and radio stations to entertain audiences. DJs blend tracks creatively and read the energy of a crowd.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 25000, max: 150000),
            educationLevel: .varies,
            icon: "headphones",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Music Therapist",
            category: "arts_entertainment",
            subcategory: "Music",
            description: "Use music to help people improve mental health, manage stress, and develop communication skills. Music therapists work in hospitals, schools, and rehabilitation centers.",
            pathway: nil,
            requiredInterests: ["audio_media", "health_wellness"],
            estimatedSalary: SalaryRange(min: 42000, max: 78000),
            educationLevel: .bachelors,
            icon: "music.note.list",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Composer",
            category: "arts_entertainment",
            subcategory: "Music",
            description: "Write original music for films, television, video games, concerts, and commercial projects. Composers use music theory and creativity to evoke emotion and tell stories.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 35000, max: 150000),
            educationLevel: .bachelors,
            icon: "pianokeys",
            color: "#E74C3C"
        ),

        // MARK: - Writing & Publishing

        CareerPath(
            title: "Author",
            category: "arts_entertainment",
            subcategory: "Writing & Publishing",
            description: "Write fiction, nonfiction, or poetry for publication as books, stories, or articles. Authors research topics deeply and craft narratives that engage readers.",
            pathway: nil,
            requiredInterests: ["creative_arts", "education"],
            estimatedSalary: SalaryRange(min: 28000, max: 150000),
            educationLevel: .varies,
            icon: "book.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Screenwriter",
            category: "arts_entertainment",
            subcategory: "Writing & Publishing",
            description: "Write scripts for films, television shows, and streaming series. Screenwriters develop characters, dialogue, and story structure for visual storytelling.",
            pathway: nil,
            requiredInterests: ["creative_arts", "audio_media"],
            estimatedSalary: SalaryRange(min: 40000, max: 200000),
            educationLevel: .bachelors,
            icon: "doc.text.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Playwright",
            category: "arts_entertainment",
            subcategory: "Writing & Publishing",
            description: "Write original scripts for stage productions, crafting dialogue and scenes that come to life through performance. Playwrights collaborate with directors and actors.",
            pathway: nil,
            requiredInterests: ["creative_arts", "education"],
            estimatedSalary: SalaryRange(min: 28000, max: 100000),
            educationLevel: .bachelors,
            icon: "quote.bubble.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Editor",
            category: "arts_entertainment",
            subcategory: "Writing & Publishing",
            description: "Review and improve written content for books, magazines, websites, and other publications. Editors work with authors to strengthen clarity, structure, and style.",
            pathway: nil,
            requiredInterests: ["creative_arts", "education"],
            estimatedSalary: SalaryRange(min: 45000, max: 95000),
            educationLevel: .bachelors,
            icon: "pencil.circle.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Copywriter",
            category: "arts_entertainment",
            subcategory: "Writing & Publishing",
            description: "Write persuasive text for advertisements, websites, and marketing campaigns. Copywriters use words to connect brands with their audiences.",
            pathway: nil,
            requiredInterests: ["creative_arts", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .bachelors,
            icon: "text.cursor",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Poet",
            category: "arts_entertainment",
            subcategory: "Writing & Publishing",
            description: "Write poetry for literary journals, books, performance, and personal expression. Poets use language, rhythm, and imagery to capture emotion and meaning.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 20000, max: 75000),
            educationLevel: .varies,
            icon: "text.quote",
            color: "#E74C3C"
        ),

        // MARK: - Crafts & Design

        CareerPath(
            title: "Jeweler",
            category: "arts_entertainment",
            subcategory: "Crafts & Design",
            description: "Design and create jewelry pieces from metals, gems, and other materials using skilled craftsmanship. Jewelers work in retail, custom commissions, and fine art.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 32000, max: 80000),
            educationLevel: .vocational,
            icon: "diamond.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Potter",
            category: "arts_entertainment",
            subcategory: "Crafts & Design",
            description: "Shape clay into functional or decorative objects using wheels, molds, and kilns. Potters sell their work through galleries, craft fairs, and online shops.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 25000, max: 65000),
            educationLevel: .varies,
            icon: "cylinder.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Fashion Designer",
            category: "arts_entertainment",
            subcategory: "Crafts & Design",
            description: "Design clothing and accessories for runways, retail stores, and custom clients. Fashion designers blend artistic vision with knowledge of fabrics, trends, and construction.",
            pathway: nil,
            requiredInterests: ["creative_arts", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 130000),
            educationLevel: .bachelors,
            icon: "scissors",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Costume Designer",
            category: "arts_entertainment",
            subcategory: "Crafts & Design",
            description: "Create costumes for film, theater, television, and special events that help bring characters to life. Costume designers research historical periods and collaborate with directors.",
            pathway: nil,
            requiredInterests: ["creative_arts", "audio_media"],
            estimatedSalary: SalaryRange(min: 38000, max: 100000),
            educationLevel: .bachelors,
            icon: "tshirt.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Tattoo Artist",
            category: "arts_entertainment",
            subcategory: "Crafts & Design",
            description: "Create permanent or temporary tattoo artwork on clients using specialized equipment and artistic skill. Tattoo artists build a portfolio and work in studios.",
            pathway: nil,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 30000, max: 100000),
            educationLevel: .vocational,
            icon: "pencil.tip.crop.circle.fill",
            color: "#E74C3C"
        ),

        // MARK: - Legacy Migrated

        CareerPath(
            title: "Graphic Designer",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Create visual content for brands, websites, and marketing materials.",
            pathway: CareerPathways.graphicDesignerPathway,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .bachelors,
            icon: "paintpalette.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Photographer",
            category: "arts_entertainment",
            subcategory: "Visual Arts",
            description: "Capture moments and tell stories through photography.",
            pathway: CareerPathways.photographerPathway,
            requiredInterests: ["creative_arts"],
            estimatedSalary: SalaryRange(min: 30000, max: 85000),
            educationLevel: .varies,
            icon: "camera.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Film Director",
            category: "arts_entertainment",
            subcategory: "Film & Television",
            description: "Direct films, commercials, and video productions.",
            pathway: CareerPathways.filmDirectorPathway,
            requiredInterests: ["creative_arts", "audio_media"],
            estimatedSalary: SalaryRange(min: 45000, max: 150000),
            educationLevel: .bachelors,
            icon: "film.fill",
            color: "#E74C3C"
        ),

        CareerPath(
            title: "Animator",
            category: "arts_entertainment",
            subcategory: "Film & Television",
            description: "Bring characters and stories to life through animation.",
            pathway: CareerPathways.animatorPathway,
            requiredInterests: ["creative_arts", "technology"],
            estimatedSalary: SalaryRange(min: 50000, max: 110000),
            educationLevel: .bachelors,
            icon: "sparkles",
            color: "#E74C3C"
        ),

    ]
}
