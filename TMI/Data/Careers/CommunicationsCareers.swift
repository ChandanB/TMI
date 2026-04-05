//
//  CommunicationsCareers.swift
//  TMI
//
//  Career data for the Communications & Media category
//

import Foundation

enum CommunicationsCareers {
    static let all: [CareerPath] = [

        // MARK: - Journalism

        CareerPath(
            title: "News Reporter",
            category: "communications",
            subcategory: "Journalism",
            description: "Gather, verify, and report on current events for newspapers, websites, television, or radio. News reporters keep communities informed about local and world happenings.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 35000, max: 90000),
            educationLevel: .bachelors,
            icon: "newspaper.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Investigative Journalist",
            category: "communications",
            subcategory: "Journalism",
            description: "Research and expose wrongdoing, corruption, or important public issues through in-depth reporting. Investigative journalists dig beneath the surface to uncover stories that matter.",
            pathway: nil,
            requiredInterests: ["audio_media", "law_government"],
            estimatedSalary: SalaryRange(min: 45000, max: 110000),
            educationLevel: .bachelors,
            icon: "magnifyingglass",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Photojournalist",
            category: "communications",
            subcategory: "Journalism",
            description: "Use photography to document and tell news stories for publications and media outlets. Photojournalists capture powerful images that accompany or stand alone as news.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 35000, max: 85000),
            educationLevel: .bachelors,
            icon: "camera.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Sports Reporter",
            category: "communications",
            subcategory: "Journalism",
            description: "Cover sporting events, interview athletes, and write or broadcast sports news and analysis. Sports reporters combine a love of sports with strong storytelling skills.",
            pathway: nil,
            requiredInterests: ["audio_media", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 35000, max: 100000),
            educationLevel: .bachelors,
            icon: "sportscourt.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Broadcast Journalist",
            category: "communications",
            subcategory: "Journalism",
            description: "Report and present news stories on television, radio, or online platforms for live audiences. Broadcast journalists research stories and deliver them clearly under pressure.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 120000),
            educationLevel: .bachelors,
            icon: "tv.fill",
            color: "#9B59B6"
        ),

        // MARK: - Public Relations

        CareerPath(
            title: "PR Specialist",
            category: "communications",
            subcategory: "Public Relations",
            description: "Manage the public image of individuals, companies, or organizations through media outreach and messaging. PR specialists write press releases, pitch stories, and build media relationships.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .bachelors,
            icon: "megaphone.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Communications Director",
            category: "communications",
            subcategory: "Public Relations",
            description: "Lead an organization's overall communication strategy across media, internal, and public channels. Communications directors shape messaging, manage teams, and protect brand reputation.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 75000, max: 160000),
            educationLevel: .bachelors,
            icon: "antenna.radiowaves.left.and.right",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Crisis Communications Manager",
            category: "communications",
            subcategory: "Public Relations",
            description: "Help organizations respond to emergencies, scandals, or public crises with clear and effective messaging. Crisis communications managers work quickly under pressure to protect reputations.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 65000, max: 140000),
            educationLevel: .bachelors,
            icon: "exclamationmark.shield.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Speechwriter",
            category: "communications",
            subcategory: "Public Relations",
            description: "Write speeches and remarks for executives, politicians, and public figures. Speechwriters capture their client's voice and craft words that inform, persuade, and inspire audiences.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 50000, max: 130000),
            educationLevel: .bachelors,
            icon: "quote.bubble.fill",
            color: "#9B59B6"
        ),

        // MARK: - Broadcasting

        CareerPath(
            title: "TV News Anchor",
            category: "communications",
            subcategory: "Broadcasting",
            description: "Present news stories on television with professionalism and authority. TV news anchors deliver breaking news, interview guests, and guide viewers through broadcasts.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 200000),
            educationLevel: .bachelors,
            icon: "tv.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "TV Producer",
            category: "communications",
            subcategory: "Broadcasting",
            description: "Oversee the production of television programs from concept through broadcast. TV producers coordinate writers, directors, crew, and talent to deliver high-quality content.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50000, max: 150000),
            educationLevel: .bachelors,
            icon: "film.stack.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Broadcast Technician",
            category: "communications",
            subcategory: "Broadcasting",
            description: "Set up, operate, and maintain equipment used to transmit audio and video for television and radio broadcasts. Broadcast technicians ensure every show sounds and looks its best.",
            pathway: nil,
            requiredInterests: ["audio_media", "technology"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .vocational,
            icon: "waveform.path.ecg",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Radio DJ",
            category: "communications",
            subcategory: "Broadcasting",
            description: "Host a radio show by playing music, chatting with listeners, and delivering entertaining content on air. Radio DJs bring energy and personality to their broadcasts.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 28000, max: 85000),
            educationLevel: .someCollege,
            icon: "radio.fill",
            color: "#9B59B6"
        ),

        // MARK: - Digital Media

        CareerPath(
            title: "Social Media Manager",
            category: "communications",
            subcategory: "Digital Media",
            description: "Manage a brand or organization's presence on social media platforms by creating content and engaging with audiences. Social media managers track analytics and grow online communities.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 95000),
            educationLevel: .bachelors,
            icon: "person.2.wave.2.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "SEO Specialist",
            category: "communications",
            subcategory: "Digital Media",
            description: "Optimize websites to rank higher in search engine results and drive organic traffic. SEO specialists use data, keywords, and technical skills to boost online visibility.",
            pathway: nil,
            requiredInterests: ["audio_media", "technology"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .bachelors,
            icon: "magnifyingglass.circle.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Digital Marketing Manager",
            category: "communications",
            subcategory: "Digital Media",
            description: "Plan and execute online marketing campaigns across email, social, search, and display channels. Digital marketing managers use data to measure results and improve performance.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "globe",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Video Editor",
            category: "communications",
            subcategory: "Digital Media",
            description: "Assemble raw footage into polished videos for YouTube, social media, television, or film. Video editors use software to shape the story, pacing, and visual style of content.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 45000, max: 110000),
            educationLevel: .bachelors,
            icon: "film.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Web Content Manager",
            category: "communications",
            subcategory: "Digital Media",
            description: "Oversee and manage the written and multimedia content on websites to ensure it is current, accurate, and engaging. Web content managers work with writers, designers, and developers.",
            pathway: nil,
            requiredInterests: ["audio_media", "technology"],
            estimatedSalary: SalaryRange(min: 50000, max: 100000),
            educationLevel: .bachelors,
            icon: "globe.badge.chevron.backward",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Influencer Manager",
            category: "communications",
            subcategory: "Digital Media",
            description: "Recruit, manage, and support social media influencers for brand partnerships and campaigns. Influencer managers negotiate deals and measure the impact of influencer content.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 105000),
            educationLevel: .bachelors,
            icon: "star.bubble.fill",
            color: "#9B59B6"
        ),

        // MARK: - Publishing & Translation

        CareerPath(
            title: "Book Publisher",
            category: "communications",
            subcategory: "Publishing & Translation",
            description: "Select, develop, and bring books to market by working with authors, editors, and marketing teams. Book publishers balance creative judgment with business decisions.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 50000, max: 120000),
            educationLevel: .bachelors,
            icon: "books.vertical.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Magazine Editor",
            category: "communications",
            subcategory: "Publishing & Translation",
            description: "Oversee the content, tone, and editorial direction of a print or digital magazine. Magazine editors assign stories, work with writers, and ensure quality and consistency.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 50000, max: 110000),
            educationLevel: .bachelors,
            icon: "newspaper",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Literary Agent",
            category: "communications",
            subcategory: "Publishing & Translation",
            description: "Represent authors by pitching their work to publishers and negotiating book deals. Literary agents help writers navigate the publishing industry and build their careers.",
            pathway: nil,
            requiredInterests: ["audio_media", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 120000),
            educationLevel: .bachelors,
            icon: "person.text.rectangle.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Translator",
            category: "communications",
            subcategory: "Publishing & Translation",
            description: "Convert written content from one language to another while preserving meaning and tone. Translators work on books, legal documents, websites, and international business materials.",
            pathway: nil,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .bachelors,
            icon: "character.bubble.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Interpreter",
            category: "communications",
            subcategory: "Publishing & Translation",
            description: "Provide real-time spoken or signed language interpretation in meetings, courts, hospitals, or conferences. Interpreters must think quickly and convey ideas accurately across languages.",
            pathway: nil,
            requiredInterests: ["audio_media", "social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 95000),
            educationLevel: .bachelors,
            icon: "waveform.and.mic",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Technical Communicator",
            category: "communications",
            subcategory: "Publishing & Translation",
            description: "Create clear technical documents, user guides, and online help content for complex products and systems. Technical communicators make specialized information accessible to everyday users.",
            pathway: nil,
            requiredInterests: ["audio_media", "technology"],
            estimatedSalary: SalaryRange(min: 55000, max: 110000),
            educationLevel: .bachelors,
            icon: "doc.text.fill",
            color: "#9B59B6"
        ),

        // MARK: - Audio & Media

        CareerPath(
            title: "Podcaster",
            category: "communications",
            subcategory: "Audio & Media",
            description: "Create and host audio shows on topics you're passionate about. Build an audience and share stories.",
            pathway: CareerPathways.podcasterPathway,
            requiredInterests: ["audio_media"],
            estimatedSalary: SalaryRange(min: 30000, max: 100000),
            educationLevel: .varies,
            icon: "mic.fill",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Radio Host",
            category: "communications",
            subcategory: "Audio & Media",
            description: "Broadcast live shows, interview guests, and connect with listeners through radio.",
            pathway: CareerPathways.radioHostPathway,
            requiredInterests: ["audio_media"],
            estimatedSalary: SalaryRange(min: 35000, max: 85000),
            educationLevel: .bachelors,
            icon: "antenna.radiowaves.left.and.right",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Audio Engineer",
            category: "communications",
            subcategory: "Audio & Media",
            description: "Mix and master sound for music, podcasts, films, and live events.",
            pathway: CareerPathways.audioEngineerPathway,
            requiredInterests: ["audio_media", "technology"],
            estimatedSalary: SalaryRange(min: 45000, max: 95000),
            educationLevel: .vocational,
            icon: "waveform",
            color: "#9B59B6"
        ),

        CareerPath(
            title: "Content Creator",
            category: "communications",
            subcategory: "Audio & Media",
            description: "Create videos, podcasts, and digital content for online platforms.",
            pathway: CareerPathways.contentCreatorPathway,
            requiredInterests: ["audio_media", "creative_arts"],
            estimatedSalary: SalaryRange(min: 25000, max: 150000),
            educationLevel: .varies,
            icon: "video.fill",
            color: "#9B59B6"
        ),

    ]
}
