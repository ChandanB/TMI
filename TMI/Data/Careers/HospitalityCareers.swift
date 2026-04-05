//
//  HospitalityCareers.swift
//  TMI
//
//  Career data for Hospitality & Tourism careers
//

import Foundation

enum HospitalityCareers {
    static let all: [CareerPath] = [

        // MARK: - Food Service

        CareerPath(
            title: "Chef",
            category: "hospitality",
            subcategory: "Food Service",
            description: "Chefs create and prepare meals in restaurants, hotels, and other food service settings, combining culinary skill with creativity and leadership. They design menus, manage kitchen staff, and ensure every dish meets high standards of taste and presentation.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 45000, max: 120000),
            educationLevel: .vocational,
            icon: "fork.knife",
            color: "#D35400"
        ),

        CareerPath(
            title: "Pastry Chef",
            category: "hospitality",
            subcategory: "Food Service",
            description: "Pastry chefs specialize in creating breads, desserts, cakes, and other baked goods that are both delicious and visually stunning. They combine artistic talent with precise culinary techniques to craft sweet masterpieces for restaurants, hotels, and bakeries.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .vocational,
            icon: "birthday.cake.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Restaurant Manager",
            category: "hospitality",
            subcategory: "Food Service",
            description: "Restaurant managers oversee the daily operations of a restaurant, from managing staff and budgets to ensuring excellent customer service. They are responsible for creating a positive dining experience and keeping the business running smoothly.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 90000),
            educationLevel: .someCollege,
            icon: "list.clipboard.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Sommelier",
            category: "hospitality",
            subcategory: "Food Service",
            description: "Sommeliers are wine specialists who curate wine lists, guide guests in selecting beverages, and pair wines with food to enhance the dining experience. They possess deep knowledge of wine regions, grape varieties, and tasting techniques.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 50000, max: 120000),
            educationLevel: .certification,
            icon: "wineglass.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Food Critic",
            category: "hospitality",
            subcategory: "Food Service",
            description: "Food critics visit restaurants and write reviews that help the public decide where to dine, while also influencing chefs and restaurant owners. This career requires excellent writing skills, a refined palate, and the ability to describe flavors and experiences vividly.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 100000),
            educationLevel: .bachelors,
            icon: "pencil.and.list.clipboard",
            color: "#D35400"
        ),

        CareerPath(
            title: "Caterer",
            category: "hospitality",
            subcategory: "Food Service",
            description: "Caterers plan and prepare food for events like weddings, corporate gatherings, and parties, coordinating everything from menus to delivery and setup. They combine culinary skills with business and logistics know-how to make events unforgettable.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .vocational,
            icon: "tray.2.fill",
            color: "#D35400"
        ),

        // MARK: - Tourism & Travel

        CareerPath(
            title: "Travel Agent",
            category: "hospitality",
            subcategory: "Tourism & Travel",
            description: "Travel agents help clients plan and book vacations, business trips, and group tours by finding the best flights, hotels, and experiences for their needs and budgets. They turn travel dreams into reality and handle all the details so travelers can relax.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 35000, max: 70000),
            educationLevel: .someCollege,
            icon: "airplane",
            color: "#D35400"
        ),

        CareerPath(
            title: "Tour Guide",
            category: "hospitality",
            subcategory: "Tourism & Travel",
            description: "Tour guides lead groups of visitors through historical sites, cultural landmarks, and natural wonders, sharing stories and knowledge to make experiences memorable. They bring destinations to life and help travelers connect with the history and culture of a place.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "social_services"],
            estimatedSalary: SalaryRange(min: 30000, max: 60000),
            educationLevel: .someCollege,
            icon: "map.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Cruise Director",
            category: "hospitality",
            subcategory: "Tourism & Travel",
            description: "Cruise directors oversee entertainment, activities, and guest services aboard cruise ships, ensuring passengers have an extraordinary experience at sea. They manage large teams, host events, and serve as the social hub of the entire voyage.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 55000, max: 110000),
            educationLevel: .bachelors,
            icon: "ferry.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Flight Attendant",
            category: "hospitality",
            subcategory: "Tourism & Travel",
            description: "Flight attendants ensure the safety and comfort of airline passengers, providing excellent service from takeoff to landing. They are trained in emergency procedures and first aid, and they get to travel to cities and countries around the world.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism"],
            estimatedSalary: SalaryRange(min: 40000, max: 85000),
            educationLevel: .someCollege,
            icon: "airplane.departure",
            color: "#D35400"
        ),

        CareerPath(
            title: "Adventure Travel Guide",
            category: "hospitality",
            subcategory: "Tourism & Travel",
            description: "Adventure travel guides lead groups on outdoor experiences such as hiking, white-water rafting, rock climbing, and wildlife safaris. They combine a love of the outdoors with leadership and safety expertise to create thrilling, unforgettable journeys.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 35000, max: 70000),
            educationLevel: .certification,
            icon: "mountain.2.fill",
            color: "#D35400"
        ),

        // MARK: - Events & Entertainment

        CareerPath(
            title: "Event Planner",
            category: "hospitality",
            subcategory: "Events & Entertainment",
            description: "Event planners organize and coordinate professional gatherings, parties, conferences, and celebrations, managing every detail from venue selection to catering and entertainment. They turn their clients' visions into seamless, memorable experiences.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 100000),
            educationLevel: .bachelors,
            icon: "party.popper.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Wedding Planner",
            category: "hospitality",
            subcategory: "Events & Entertainment",
            description: "Wedding planners help couples plan and execute the perfect wedding day, managing vendors, timelines, budgets, and all the little details that make the event special. It takes strong organizational skills, creativity, and the ability to stay calm under pressure.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 90000),
            educationLevel: .bachelors,
            icon: "heart.circle.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Convention Manager",
            category: "hospitality",
            subcategory: "Events & Entertainment",
            description: "Convention managers organize large-scale conferences and trade shows, coordinating venues, exhibitors, speakers, and thousands of attendees. They work for convention centers, hotels, and professional associations to execute high-impact events.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55000, max: 110000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Meeting Coordinator",
            category: "hospitality",
            subcategory: "Events & Entertainment",
            description: "Meeting coordinators plan and manage corporate meetings, seminars, and retreats, handling logistics such as travel, catering, and audiovisual equipment. They ensure that every detail is in place so that meetings run efficiently and productively.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .bachelors,
            icon: "calendar.badge.checkmark",
            color: "#D35400"
        ),

        CareerPath(
            title: "Festival Organizer",
            category: "hospitality",
            subcategory: "Events & Entertainment",
            description: "Festival organizers plan and manage large public events such as music festivals, food fairs, and cultural celebrations that bring communities together. They coordinate permits, vendors, artists, volunteers, and safety plans to create exciting, memorable events.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "creative_arts"],
            estimatedSalary: SalaryRange(min: 40000, max: 85000),
            educationLevel: .bachelors,
            icon: "music.note.list",
            color: "#D35400"
        ),

        // MARK: - Hotels & Lodging

        CareerPath(
            title: "Hotel Manager",
            category: "hospitality",
            subcategory: "Hotels & Lodging",
            description: "Hotel managers oversee the complete operation of a hotel, from front desk and housekeeping to dining and guest services. They lead large teams and make decisions that ensure every guest has a comfortable, enjoyable stay.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "bed.double.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Concierge",
            category: "hospitality",
            subcategory: "Hotels & Lodging",
            description: "Concierges are hospitality experts at hotels and resorts who assist guests with everything from restaurant reservations and tour bookings to special requests and local recommendations. They use their extensive local knowledge to create personalized, five-star experiences.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "social_services"],
            estimatedSalary: SalaryRange(min: 35000, max: 70000),
            educationLevel: .someCollege,
            icon: "star.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Resort Director",
            category: "hospitality",
            subcategory: "Hotels & Lodging",
            description: "Resort directors manage all aspects of a resort's operations, including amenities, staff, marketing, and guest experience. They set the vision for the property and ensure that the resort remains a top destination for travelers and vacationers.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 80000, max: 180000),
            educationLevel: .bachelors,
            icon: "sun.max.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Housekeeping Manager",
            category: "hospitality",
            subcategory: "Hotels & Lodging",
            description: "Housekeeping managers oversee the cleaning and maintenance staff at hotels and resorts, ensuring every room meets high cleanliness and presentation standards. Strong leadership and attention to detail are essential in this behind-the-scenes but critical role.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism"],
            estimatedSalary: SalaryRange(min: 40000, max: 75000),
            educationLevel: .someCollege,
            icon: "sparkles",
            color: "#D35400"
        ),

        CareerPath(
            title: "Bed and Breakfast Owner",
            category: "hospitality",
            subcategory: "Hotels & Lodging",
            description: "Bed and breakfast owners operate small, intimate lodging businesses that offer personalized service and homemade breakfasts to travelers. They manage everything from bookings and marketing to cooking and maintenance, creating a warm home-away-from-home experience.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 35000, max: 90000),
            educationLevel: .varies,
            icon: "house.fill",
            color: "#D35400"
        ),

        // MARK: - Recreation

        CareerPath(
            title: "Recreation Director",
            category: "hospitality",
            subcategory: "Recreation",
            description: "Recreation directors design and manage leisure programs and activities for communities, resorts, or organizations to promote health and well-being. They oversee staff, facilities, and budgets to provide engaging programming for people of all ages.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 45000, max: 90000),
            educationLevel: .bachelors,
            icon: "figure.pool.swim",
            color: "#D35400"
        ),

        CareerPath(
            title: "Spa Manager",
            category: "hospitality",
            subcategory: "Recreation",
            description: "Spa managers oversee the operations of a spa facility, managing staff, services, and the serene guest experience that keeps clients coming back. They combine wellness knowledge with business skills to run a relaxing, profitable environment.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45000, max: 90000),
            educationLevel: .someCollege,
            icon: "leaf.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Casino Manager",
            category: "hospitality",
            subcategory: "Recreation",
            description: "Casino managers oversee the gaming floor, staff, and operations of a casino to ensure a safe, fair, and entertaining experience for guests. They must understand gaming regulations, customer service, and business management to keep the operation running successfully.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60000, max: 130000),
            educationLevel: .bachelors,
            icon: "suit.spade.fill",
            color: "#D35400"
        ),

        CareerPath(
            title: "Campground Manager",
            category: "hospitality",
            subcategory: "Recreation",
            description: "Campground managers operate and maintain campgrounds and outdoor recreational facilities for visitors who want to connect with nature. They handle reservations, maintenance, and guest services while fostering a love of the outdoors in every camper.",
            pathway: nil,
            requiredInterests: ["hospitality_tourism", "sports_athletics"],
            estimatedSalary: SalaryRange(min: 35000, max: 65000),
            educationLevel: .someCollege,
            icon: "tent.fill",
            color: "#D35400"
        )
    ]
}
