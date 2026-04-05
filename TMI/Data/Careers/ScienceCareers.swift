//
//  ScienceCareers.swift
//  TMI
//
//  Career data for the Science category (30 careers)
//

import Foundation

enum ScienceCareers {
    static let all: [CareerPath] = [

        // MARK: - Life Sciences

        CareerPath(
            title: "Biologist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Biologists study living organisms—from tiny bacteria to complex ecosystems—to understand how life works and evolves. They conduct experiments, analyze data, and publish findings that advance our understanding of the natural world.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 55_000, max: 105_000),
            educationLevel: .bachelors,
            icon: "leaf.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Microbiologist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Microbiologists study microscopic organisms like bacteria, viruses, and fungi to understand how they affect human health, agriculture, and the environment. Their research leads to advances in medicine, food safety, and environmental cleanup.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 60_000, max: 115_000),
            educationLevel: .masters,
            icon: "allergens.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Geneticist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Geneticists study DNA and genes to understand how traits are inherited and how genetic mutations cause diseases. Their work is at the forefront of personalized medicine, agriculture, and forensic science.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 65_000, max: 125_000),
            educationLevel: .doctorate,
            icon: "dna",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Biochemist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Biochemists explore the chemical processes that happen inside living cells, studying molecules like proteins, DNA, and enzymes. Their discoveries help develop new medicines, improve crop yields, and explain how diseases develop.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 62_000, max: 120_000),
            educationLevel: .doctorate,
            icon: "flask.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Botanist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Botanists study plants—how they grow, reproduce, and interact with their environment—to advance fields like agriculture, medicine, and conservation. They may work in labs, greenhouses, or conduct fieldwork in diverse ecosystems around the world.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 50_000, max: 95_000),
            educationLevel: .masters,
            icon: "tree.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Neuroscientist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Neuroscientists study the brain and nervous system to understand how we think, feel, learn, and behave. Their research helps explain mental illness, develop treatments for neurological disorders, and unlock the mysteries of human consciousness.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 75_000, max: 145_000),
            educationLevel: .doctorate,
            icon: "brain.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Pharmacologist",
            category: "science",
            subcategory: "Life Sciences",
            description: "Pharmacologists study how drugs interact with the body to develop safer and more effective medicines. They design experiments, analyze results, and work closely with pharmaceutical companies and research institutions to bring new treatments to patients.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 70_000, max: 135_000),
            educationLevel: .doctorate,
            icon: "pills.fill",
            color: "#2980B9"
        ),

        // MARK: - Physical Sciences

        CareerPath(
            title: "Physicist",
            category: "science",
            subcategory: "Physical Sciences",
            description: "Physicists study the fundamental laws of nature—from the motion of objects to the behavior of subatomic particles—to understand how the universe works. Their discoveries have led to technologies like lasers, semiconductors, and medical imaging devices.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 70_000, max: 140_000),
            educationLevel: .doctorate,
            icon: "atom",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Astrophysicist",
            category: "science",
            subcategory: "Physical Sciences",
            description: "Astrophysicists study the physical properties of stars, galaxies, black holes, and other objects in the universe using telescopes and advanced mathematics. Their research expands our understanding of how the universe began and how it continues to evolve.",
            pathway: nil,
            requiredInterests: ["science_research", "technology"],
            estimatedSalary: SalaryRange(min: 75_000, max: 150_000),
            educationLevel: .doctorate,
            icon: "sparkles",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Chemist",
            category: "science",
            subcategory: "Physical Sciences",
            description: "Chemists study the composition, structure, and properties of matter to develop new materials, medicines, and industrial processes. They work in labs to conduct experiments and find solutions to challenges in energy, healthcare, and manufacturing.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 58_000, max: 115_000),
            educationLevel: .bachelors,
            icon: "flask.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Materials Scientist",
            category: "science",
            subcategory: "Physical Sciences",
            description: "Materials scientists design and study the properties of metals, polymers, ceramics, and composites to create stronger, lighter, and more efficient materials. Their work is behind innovations like body armor, flexible electronics, and aerospace components.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 65_000, max: 120_000),
            educationLevel: .masters,
            icon: "cube.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Nuclear Physicist",
            category: "science",
            subcategory: "Physical Sciences",
            description: "Nuclear physicists study the structure of atomic nuclei and the forces that hold them together to advance energy generation, medical imaging, and national security. They work at research facilities and help design safer and more efficient nuclear technologies.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 80_000, max: 155_000),
            educationLevel: .doctorate,
            icon: "atom",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Quantum Computing Researcher",
            category: "science",
            subcategory: "Physical Sciences",
            description: "Quantum computing researchers develop next-generation computers that use the principles of quantum physics to solve problems that are impossible for traditional computers. Their cutting-edge work is expected to transform fields like cryptography, drug discovery, and artificial intelligence.",
            pathway: nil,
            requiredInterests: ["science_research", "technology"],
            estimatedSalary: SalaryRange(min: 90_000, max: 180_000),
            educationLevel: .doctorate,
            icon: "waveform.path",
            color: "#2980B9"
        ),

        // MARK: - Earth Sciences

        CareerPath(
            title: "Geologist",
            category: "science",
            subcategory: "Earth Sciences",
            description: "Geologists study the structure, composition, and history of the Earth by examining rocks, minerals, and landforms. Their work supports natural resource exploration, environmental protection, and understanding geological hazards like earthquakes and landslides.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 58_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "mountain.2.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Seismologist",
            category: "science",
            subcategory: "Earth Sciences",
            description: "Seismologists study earthquakes and seismic waves to understand the structure of the Earth and help predict and prepare for dangerous ground shaking. Their research is critical for designing earthquake-resistant buildings and warning systems.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 65_000, max: 120_000),
            educationLevel: .masters,
            icon: "waveform",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Paleontologist",
            category: "science",
            subcategory: "Earth Sciences",
            description: "Paleontologists study fossils of ancient plants and animals to piece together the history of life on Earth, including understanding mass extinctions and evolutionary changes over millions of years. They conduct fieldwork to excavate specimens and analyze them in the lab.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 52_000, max: 100_000),
            educationLevel: .doctorate,
            icon: "fossil.shell.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Volcanologist",
            category: "science",
            subcategory: "Earth Sciences",
            description: "Volcanologists study volcanoes and volcanic activity to understand how eruptions happen and improve early warning systems that protect nearby communities. They collect gas samples, monitor seismic activity, and sometimes venture close to active lava flows.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .masters,
            icon: "flame.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Geographer",
            category: "science",
            subcategory: "Earth Sciences",
            description: "Geographers study the physical features of the Earth and how humans interact with their environment, using maps and spatial data to solve real-world problems. They work in fields like urban planning, environmental management, and international development.",
            pathway: nil,
            requiredInterests: ["science_research", "law_government"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .bachelors,
            icon: "globe.americas.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Astronomer",
            category: "science",
            subcategory: "Earth Sciences",
            description: "Astronomers observe and study celestial objects like planets, stars, and galaxies using telescopes and data analysis to understand the cosmos. They work at observatories, universities, and space agencies to expand humanity's knowledge of the universe.",
            pathway: nil,
            requiredInterests: ["science_research", "technology"],
            estimatedSalary: SalaryRange(min: 68_000, max: 140_000),
            educationLevel: .doctorate,
            icon: "moon.stars.fill",
            color: "#2980B9"
        ),

        // MARK: - Research & Lab

        CareerPath(
            title: "Lab Technician",
            category: "science",
            subcategory: "Research & Lab",
            description: "Lab technicians perform experiments, maintain equipment, and collect data under the direction of scientists and researchers across many fields. They are essential team members in medical, pharmaceutical, environmental, and industrial labs.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 38_000, max: 70_000),
            educationLevel: .someCollege,
            icon: "testtube.2",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Research Scientist",
            category: "science",
            subcategory: "Research & Lab",
            description: "Research scientists design and conduct studies to answer complex scientific questions and push the boundaries of human knowledge in fields like biology, chemistry, and physics. They analyze results, write papers, and collaborate with other experts to advance their field.",
            pathway: nil,
            requiredInterests: ["science_research", "technology"],
            estimatedSalary: SalaryRange(min: 70_000, max: 130_000),
            educationLevel: .doctorate,
            icon: "magnifyingglass.circle.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Clinical Research Coordinator",
            category: "science",
            subcategory: "Research & Lab",
            description: "Clinical research coordinators manage the day-to-day operations of medical studies and clinical trials, ensuring they follow safety protocols and ethical guidelines. They recruit participants, collect data, and work closely with physicians and pharmaceutical sponsors.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 48_000, max: 85_000),
            educationLevel: .bachelors,
            icon: "clipboard.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Biostatistician",
            category: "science",
            subcategory: "Research & Lab",
            description: "Biostatisticians use advanced math and statistics to design research studies and analyze biological and medical data, ensuring that scientific conclusions are valid and reliable. Their work is critical for approving new drugs and understanding public health trends.",
            pathway: nil,
            requiredInterests: ["science_research", "technology"],
            estimatedSalary: SalaryRange(min: 75_000, max: 135_000),
            educationLevel: .masters,
            icon: "function",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Science Writer",
            category: "science",
            subcategory: "Research & Lab",
            description: "Science writers translate complex scientific discoveries into clear, engaging content for the public through articles, books, podcasts, and documentaries. They bridge the gap between researchers and general audiences, making science accessible and exciting for everyone.",
            pathway: nil,
            requiredInterests: ["science_research", "audio_media"],
            estimatedSalary: SalaryRange(min: 48_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "doc.text.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Patent Examiner",
            category: "science",
            subcategory: "Research & Lab",
            description: "Patent examiners review applications for new inventions to determine if they are truly novel and meet the legal requirements for a patent. They use their technical expertise in science or engineering to assess whether an idea deserves intellectual property protection.",
            pathway: nil,
            requiredInterests: ["science_research", "law_government"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "checkmark.seal.fill",
            color: "#2980B9"
        ),

        // MARK: - Applied Sciences

        CareerPath(
            title: "Data Scientist",
            category: "science",
            subcategory: "Applied Sciences",
            description: "Data scientists collect, analyze, and interpret massive amounts of data to help organizations make smarter decisions and discover hidden patterns. They combine skills in statistics, programming, and domain knowledge to solve real-world problems.",
            pathway: nil,
            requiredInterests: ["science_research", "technology"],
            estimatedSalary: SalaryRange(min: 85_000, max: 160_000),
            educationLevel: .masters,
            icon: "chart.bar.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Forensic Scientist",
            category: "science",
            subcategory: "Applied Sciences",
            description: "Forensic scientists apply chemistry, biology, and physics to analyze physical evidence from crime scenes and provide objective findings for legal investigations. They work in crime labs and may testify in court as expert witnesses.",
            pathway: nil,
            requiredInterests: ["science_research", "law_government"],
            estimatedSalary: SalaryRange(min: 52_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "magnifyingglass",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Toxicologist",
            category: "science",
            subcategory: "Applied Sciences",
            description: "Toxicologists study the harmful effects of chemicals and substances on living organisms to protect human health and the environment. They work in fields ranging from pharmaceutical testing to environmental regulation to criminal investigations.",
            pathway: nil,
            requiredInterests: ["science_research", "health_wellness"],
            estimatedSalary: SalaryRange(min: 62_000, max: 115_000),
            educationLevel: .masters,
            icon: "exclamationmark.triangle.fill",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Nanotechnologist",
            category: "science",
            subcategory: "Applied Sciences",
            description: "Nanotechnologists engineer materials and devices at the incredibly small scale of individual atoms and molecules to create breakthroughs in medicine, electronics, and energy. Their work is leading to innovations like targeted cancer treatments and ultra-efficient solar cells.",
            pathway: nil,
            requiredInterests: ["science_research", "engineering_building"],
            estimatedSalary: SalaryRange(min: 75_000, max: 145_000),
            educationLevel: .doctorate,
            icon: "atom",
            color: "#2980B9"
        ),

        CareerPath(
            title: "Atmospheric Scientist",
            category: "science",
            subcategory: "Applied Sciences",
            description: "Atmospheric scientists study the Earth's atmosphere, weather patterns, and climate systems to improve weather forecasting and understand climate change. They use satellites, weather stations, and computer models to analyze data and communicate findings to the public and policymakers.",
            pathway: nil,
            requiredInterests: ["science_research", "agriculture_nature"],
            estimatedSalary: SalaryRange(min: 62_000, max: 115_000),
            educationLevel: .masters,
            icon: "cloud.sun.fill",
            color: "#2980B9"
        )
    ]
}
