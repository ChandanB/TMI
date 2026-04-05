//
//  HealthcareCareers.swift
//  TMI
//
//  Career data for Healthcare careers
//

import Foundation

enum HealthcareCareers {
    static let all: [CareerPath] = [

        // MARK: - Medical

        CareerPath(
            title: "Physician",
            category: "healthcare",
            subcategory: "Medical",
            description: "Physicians diagnose and treat illnesses, injuries, and medical conditions to help patients live healthier lives. They examine patients, order tests, and prescribe treatments, working in hospitals, clinics, and private practices.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 200000, max: 400000),
            educationLevel: .doctorate,
            icon: "stethoscope",
            color: "#16A085"
        ),

        CareerPath(
            title: "Surgeon",
            category: "healthcare",
            subcategory: "Medical",
            description: "Surgeons perform operations to treat injuries, diseases, and deformities, requiring exceptional precision and years of rigorous training. They work in operating rooms and lead a team of medical professionals to ensure patient safety.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 300000, max: 600000),
            educationLevel: .doctorate,
            icon: "cross.case.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Pediatrician",
            category: "healthcare",
            subcategory: "Medical",
            description: "Pediatricians specialize in the health and development of children from birth through young adulthood, providing checkups and treating illnesses. They build lasting relationships with families to support children's growth and well-being.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 175000, max: 300000),
            educationLevel: .doctorate,
            icon: "figure.and.child.holdinghands",
            color: "#16A085"
        ),

        CareerPath(
            title: "Cardiologist",
            category: "healthcare",
            subcategory: "Medical",
            description: "Cardiologists are heart specialists who diagnose and treat conditions of the heart and blood vessels. They perform tests, read imaging results, and may perform procedures to help patients with heart disease live longer, healthier lives.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 350000, max: 650000),
            educationLevel: .doctorate,
            icon: "heart.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Dermatologist",
            category: "healthcare",
            subcategory: "Medical",
            description: "Dermatologists diagnose and treat conditions of the skin, hair, and nails, from acne and eczema to skin cancer. They combine medical expertise with cosmetic treatments to help patients look and feel their best.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 300000, max: 550000),
            educationLevel: .doctorate,
            icon: "bandage.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Anesthesiologist",
            category: "healthcare",
            subcategory: "Medical",
            description: "Anesthesiologists administer medications that keep patients comfortable and pain-free during surgeries and other medical procedures. They monitor vital signs throughout operations and are critical to patient safety in the operating room.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 350000, max: 600000),
            educationLevel: .doctorate,
            icon: "syringe.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Emergency Room Doctor",
            category: "healthcare",
            subcategory: "Medical",
            description: "Emergency room doctors treat patients with sudden and serious illnesses or injuries that require immediate attention. They must think quickly, handle high-pressure situations, and make fast decisions to save lives every day.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 250000, max: 450000),
            educationLevel: .doctorate,
            icon: "bolt.heart.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Paramedic",
            category: "healthcare",
            subcategory: "Medical",
            description: "Paramedics provide emergency medical care to patients before and during transport to the hospital, often saving lives in critical moments. They respond to 911 calls, perform advanced medical procedures, and work closely with emergency room teams.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 80000),
            educationLevel: .someCollege,
            icon: "staroflife.fill",
            color: "#16A085"
        ),

        // MARK: - Dental

        CareerPath(
            title: "Dentist",
            category: "healthcare",
            subcategory: "Dental",
            description: "Dentists diagnose and treat problems with teeth, gums, and the mouth to help patients maintain healthy smiles. They perform fillings, extractions, and cleanings, and educate patients on proper oral hygiene habits.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 150000, max: 300000),
            educationLevel: .doctorate,
            icon: "mouth.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Dental Hygienist",
            category: "healthcare",
            subcategory: "Dental",
            description: "Dental hygienists clean teeth, examine patients for signs of oral disease, and teach patients how to care for their teeth and gums. They work alongside dentists and play a key role in helping patients prevent serious dental problems.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 55000, max: 100000),
            educationLevel: .someCollege,
            icon: "cross.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Dental Assistant",
            category: "healthcare",
            subcategory: "Dental",
            description: "Dental assistants support dentists during procedures, prepare equipment, and help patients feel comfortable during their visits. It is a hands-on healthcare role that combines patient care with technical skills in a dental office setting.",
            pathway: nil,
            requiredInterests: ["health_wellness"],
            estimatedSalary: SalaryRange(min: 35000, max: 60000),
            educationLevel: .certification,
            icon: "heart.text.square.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Orthodontist",
            category: "healthcare",
            subcategory: "Dental",
            description: "Orthodontists are dental specialists who correct misaligned teeth and jaws using braces, aligners, and other devices. They create customized treatment plans that help patients achieve healthier bites and more confident smiles.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 200000, max: 400000),
            educationLevel: .doctorate,
            icon: "mouth",
            color: "#16A085"
        ),

        // MARK: - Mental Health

        CareerPath(
            title: "Psychologist",
            category: "healthcare",
            subcategory: "Mental Health",
            description: "Psychologists study human behavior and mental processes to help people understand and overcome emotional challenges. They conduct research, perform assessments, and provide therapy to improve the mental health of individuals and communities.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 70000, max: 140000),
            educationLevel: .doctorate,
            icon: "brain.head.profile",
            color: "#16A085"
        ),

        CareerPath(
            title: "Clinical Psychologist",
            category: "healthcare",
            subcategory: "Mental Health",
            description: "Clinical psychologists assess and treat serious mental, behavioral, and emotional disorders through therapy and evidence-based interventions. They work in hospitals, clinics, and private practice to help people with conditions like depression, anxiety, and trauma.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 80000, max: 150000),
            educationLevel: .doctorate,
            icon: "brain",
            color: "#16A085"
        ),

        CareerPath(
            title: "Marriage and Family Therapist",
            category: "healthcare",
            subcategory: "Mental Health",
            description: "Marriage and family therapists help couples and families work through relationship challenges, communication problems, and life transitions. They use talk therapy techniques to strengthen bonds and improve the emotional health of the whole family.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 55000, max: 110000),
            educationLevel: .masters,
            icon: "person.2.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Substance Abuse Counselor",
            category: "healthcare",
            subcategory: "Mental Health",
            description: "Substance abuse counselors help people overcome addiction to drugs or alcohol by providing counseling, support, and recovery strategies. They work in treatment centers, hospitals, and community organizations to guide clients toward healthier lives.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 80000),
            educationLevel: .bachelors,
            icon: "hand.raised.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Art Therapist",
            category: "healthcare",
            subcategory: "Mental Health",
            description: "Art therapists use creative activities like drawing, painting, and sculpting as tools to help people express emotions and heal from trauma or mental illness. They work in hospitals, schools, and clinics, combining artistic and therapeutic techniques.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 85000),
            educationLevel: .masters,
            icon: "paintpalette.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Psychiatrist",
            category: "healthcare",
            subcategory: "Mental Health",
            description: "Psychiatrists are medical doctors who specialize in diagnosing and treating mental health disorders, including the ability to prescribe medication. They often work alongside psychologists and therapists to provide comprehensive mental health care.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 200000, max: 380000),
            educationLevel: .doctorate,
            icon: "brain.filled.head.profile",
            color: "#16A085"
        ),

        // MARK: - Allied Health

        CareerPath(
            title: "Occupational Therapist",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Occupational therapists help people who have been injured or have disabilities regain the ability to perform everyday tasks like cooking, dressing, and working. They develop personalized treatment plans and teach adaptive techniques to restore independence.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 70000, max: 115000),
            educationLevel: .masters,
            icon: "figure.roll",
            color: "#16A085"
        ),

        CareerPath(
            title: "Respiratory Therapist",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Respiratory therapists treat patients with breathing disorders and lung conditions such as asthma, pneumonia, and sleep apnea. They operate ventilators, administer breathing treatments, and educate patients on managing respiratory illnesses.",
            pathway: nil,
            requiredInterests: ["health_wellness", "technology"],
            estimatedSalary: SalaryRange(min: 55000, max: 95000),
            educationLevel: .someCollege,
            icon: "lungs.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Audiologist",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Audiologists diagnose and treat hearing and balance disorders, fitting patients with hearing aids and developing hearing rehabilitation plans. They work with people of all ages, from newborns to the elderly, to improve communication and quality of life.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 75000, max: 130000),
            educationLevel: .doctorate,
            icon: "ear.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Optometrist",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Optometrists examine eyes for vision problems and diseases, prescribing glasses, contact lenses, and treatments to improve sight. They are often the first health professionals to detect conditions like diabetes and high blood pressure through eye exams.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 115000, max: 200000),
            educationLevel: .doctorate,
            icon: "eye.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Chiropractor",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Chiropractors diagnose and treat musculoskeletal disorders, especially problems with the spine, using hands-on spinal manipulation and other techniques. They help patients reduce pain and improve mobility without surgery or medication.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 70000, max: 150000),
            educationLevel: .doctorate,
            icon: "figure.stand",
            color: "#16A085"
        ),

        CareerPath(
            title: "Surgical Technologist",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Surgical technologists prepare operating rooms, sterilize equipment, and assist surgeons during procedures by passing instruments and maintaining a sterile field. They are essential members of the surgical team, ensuring operations run smoothly and safely.",
            pathway: nil,
            requiredInterests: ["health_wellness", "technology"],
            estimatedSalary: SalaryRange(min: 45000, max: 80000),
            educationLevel: .someCollege,
            icon: "scissors",
            color: "#16A085"
        ),

        CareerPath(
            title: "Nurse Practitioner",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Nurse practitioners are advanced practice nurses who can diagnose conditions, prescribe medications, and manage patient care independently or alongside physicians. They often serve as primary care providers, especially in underserved communities.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 100000, max: 180000),
            educationLevel: .masters,
            icon: "cross.circle.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Midwife",
            category: "healthcare",
            subcategory: "Allied Health",
            description: "Midwives provide care for pregnant women during pregnancy, childbirth, and the postpartum period, supporting both mother and newborn. They take a holistic, patient-centered approach to one of the most important moments in a family's life.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 90000, max: 150000),
            educationLevel: .masters,
            icon: "figure.maternity",
            color: "#16A085"
        ),

        // MARK: - Pharmacy & Research

        CareerPath(
            title: "Pharmacist",
            category: "healthcare",
            subcategory: "Pharmacy & Research",
            description: "Pharmacists dispense prescription medications, advise patients on drug interactions, and ensure medications are used safely and effectively. They are trusted healthcare experts who play a vital role in managing patients' overall health.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 120000, max: 180000),
            educationLevel: .doctorate,
            icon: "pills.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Pharmacy Technician",
            category: "healthcare",
            subcategory: "Pharmacy & Research",
            description: "Pharmacy technicians assist pharmacists by preparing and dispensing medications, managing inventory, and processing prescriptions. It is a hands-on healthcare role that requires attention to detail and strong knowledge of medications.",
            pathway: nil,
            requiredInterests: ["health_wellness", "technology"],
            estimatedSalary: SalaryRange(min: 35000, max: 60000),
            educationLevel: .certification,
            icon: "pill.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Medical Lab Technician",
            category: "healthcare",
            subcategory: "Pharmacy & Research",
            description: "Medical lab technicians analyze blood, tissue, and other samples to help doctors diagnose and treat diseases. They work in hospital and clinical laboratories, using sophisticated equipment to produce accurate results that guide patient care.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 45000, max: 80000),
            educationLevel: .someCollege,
            icon: "flask.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Epidemiologist",
            category: "healthcare",
            subcategory: "Pharmacy & Research",
            description: "Epidemiologists are disease detectives who study how illnesses spread through populations and work to prevent outbreaks. They collect and analyze health data to identify risk factors and develop strategies to protect public health.",
            pathway: nil,
            requiredInterests: ["health_wellness", "science_research"],
            estimatedSalary: SalaryRange(min: 70000, max: 130000),
            educationLevel: .masters,
            icon: "waveform.path.ecg",
            color: "#16A085"
        ),

        CareerPath(
            title: "Public Health Educator",
            category: "healthcare",
            subcategory: "Pharmacy & Research",
            description: "Public health educators develop programs and campaigns that teach communities how to live healthier lives and prevent illness. They work for schools, nonprofits, and government agencies to promote wellness and change health behaviors.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 45000, max: 90000),
            educationLevel: .bachelors,
            icon: "megaphone.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Health Information Technician",
            category: "healthcare",
            subcategory: "Pharmacy & Research",
            description: "Health information technicians manage patient records and ensure medical data is accurate, organized, and secure. They use technology and coding systems to classify diagnoses and procedures, supporting billing, research, and quality care.",
            pathway: nil,
            requiredInterests: ["health_wellness", "technology"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .someCollege,
            icon: "folder.fill.badge.person.crop",
            color: "#16A085"
        ),

        // MARK: - EMT & Support

        CareerPath(
            title: "EMT",
            category: "healthcare",
            subcategory: "EMT & Support",
            description: "EMTs (Emergency Medical Technicians) respond to emergency calls and provide basic medical care to patients before and during transport to the hospital. They are often the first medical help to arrive in a crisis and must act fast under pressure.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 35000, max: 65000),
            educationLevel: .certification,
            icon: "staroflife.circle.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Medical Assistant",
            category: "healthcare",
            subcategory: "EMT & Support",
            description: "Medical assistants support physicians and nurses in clinics and medical offices by taking vital signs, preparing patients for exams, and handling administrative tasks. They are a key part of delivering efficient, compassionate care.",
            pathway: nil,
            requiredInterests: ["health_wellness", "technology"],
            estimatedSalary: SalaryRange(min: 35000, max: 60000),
            educationLevel: .certification,
            icon: "clipboard.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Home Health Aide",
            category: "healthcare",
            subcategory: "EMT & Support",
            description: "Home health aides assist elderly, disabled, or recovering patients with daily tasks like bathing, dressing, and taking medications in their own homes. This compassionate role makes a direct difference in the comfort and independence of vulnerable individuals.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 28000, max: 50000),
            educationLevel: .highSchool,
            icon: "house.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Patient Care Coordinator",
            category: "healthcare",
            subcategory: "EMT & Support",
            description: "Patient care coordinators organize and oversee the care plans of patients, ensuring they receive the right services and follow-up appointments. They serve as a bridge between patients, families, and healthcare providers to deliver smooth, continuous care.",
            pathway: nil,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .bachelors,
            icon: "person.crop.circle.badge.checkmark",
            color: "#16A085"
        ),

        // MARK: - Legacy Migrated

        CareerPath(
            title: "Fitness Trainer",
            category: "healthcare",
            subcategory: "Wellness & Fitness",
            description: "Help people achieve their health and fitness goals.",
            pathway: CareerPathways.fitnessTrainerPathway,
            requiredInterests: ["health_wellness", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 35000, max: 75000),
            educationLevel: .certification,
            icon: "figure.strengthtraining.traditional",
            color: "#16A085"
        ),

        CareerPath(
            title: "Nutritionist",
            category: "healthcare",
            subcategory: "Wellness & Fitness",
            description: "Guide people toward healthier eating and lifestyle choices.",
            pathway: CareerPathways.nutritionistPathway,
            requiredInterests: ["health_wellness"],
            estimatedSalary: SalaryRange(min: 45000, max: 85000),
            educationLevel: .bachelors,
            icon: "leaf.fill",
            color: "#16A085"
        ),

        CareerPath(
            title: "Physical Therapist",
            category: "healthcare",
            subcategory: "Therapy & Rehabilitation",
            description: "Help patients recover from injuries and improve mobility.",
            pathway: CareerPathways.physicalTherapistPathway,
            requiredInterests: ["health_wellness"],
            estimatedSalary: SalaryRange(min: 65000, max: 105000),
            educationLevel: .doctorate,
            icon: "figure.walk",
            color: "#16A085"
        ),

        CareerPath(
            title: "Nurse",
            category: "healthcare",
            subcategory: "Nursing",
            description: "Provide care and support to patients in hospitals and clinics.",
            pathway: CareerPathways.nursePathway,
            requiredInterests: ["health_wellness", "social_services"],
            estimatedSalary: SalaryRange(min: 55000, max: 95000),
            educationLevel: .bachelors,
            icon: "cross.case.fill",
            color: "#16A085"
        )
    ]
}
