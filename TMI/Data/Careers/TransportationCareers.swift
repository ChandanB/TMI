//
//  TransportationCareers.swift
//  TMI
//
//  Career data for the Transportation category (20 careers)
//

import Foundation

enum TransportationCareers {
    static let all: [CareerPath] = [

        // MARK: - Aviation

        CareerPath(
            title: "Commercial Pilot",
            category: "transportation",
            subcategory: "Aviation",
            description: "Commercial pilots fly aircraft for airlines and charter services, transporting passengers and cargo safely across short and long distances. They operate complex flight systems, communicate with air traffic control, and make critical decisions to ensure every flight arrives safely.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "engineering_building"],
            estimatedSalary: SalaryRange(min: 80_000, max: 200_000),
            educationLevel: .certification,
            icon: "airplane",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Airline Pilot",
            category: "transportation",
            subcategory: "Aviation",
            description: "Airline pilots captain large commercial jets for major airlines, responsible for the safety of hundreds of passengers and crew on every flight. They undergo rigorous training, accumulate thousands of flight hours, and follow precise checklists and procedures to operate aircraft in all weather conditions.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "engineering_building"],
            estimatedSalary: SalaryRange(min: 100_000, max: 300_000),
            educationLevel: .bachelors,
            icon: "airplane.circle.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Air Traffic Controller",
            category: "transportation",
            subcategory: "Aviation",
            description: "Air traffic controllers guide aircraft safely through airspace by communicating with pilots and coordinating the takeoff, landing, and routing of hundreds of flights per day. They use radar, radio, and computer systems to prevent collisions and keep air traffic moving efficiently.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "technology"],
            estimatedSalary: SalaryRange(min: 75_000, max: 175_000),
            educationLevel: .bachelors,
            icon: "antenna.radiowaves.left.and.right.circle.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Aircraft Mechanic",
            category: "transportation",
            subcategory: "Aviation",
            description: "Aircraft mechanics inspect, repair, and maintain airplanes and helicopters to ensure they are airworthy and safe to fly, following strict FAA regulations and manufacturer guidelines. They troubleshoot engine problems, replace worn components, and sign off on maintenance records that certify an aircraft is ready for flight.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "engineering_building"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .vocational,
            icon: "wrench.and.screwdriver.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Flight Dispatcher",
            category: "transportation",
            subcategory: "Aviation",
            description: "Flight dispatchers work alongside pilots from the ground, planning flight routes, calculating fuel loads, and monitoring weather to ensure every departure is safe and efficient. They share legal responsibility with the captain for flight safety and can delay or cancel flights if conditions are unsafe.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "technology"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .certification,
            icon: "map.fill",
            color: "#5D6D7E"
        ),

        // MARK: - Maritime

        CareerPath(
            title: "Ship Captain",
            category: "transportation",
            subcategory: "Maritime",
            description: "Ship captains command large vessels including cargo ships, tankers, and passenger ferries, responsible for the safety of the ship, crew, cargo, and passengers throughout every voyage. They navigate using charts and electronic systems, manage the crew, and make final decisions on all aspects of the ship's operation.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 90_000, max: 180_000),
            educationLevel: .bachelors,
            icon: "ferry.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Port Manager",
            category: "transportation",
            subcategory: "Maritime",
            description: "Port managers oversee the operations of shipping ports and marine terminals, coordinating the movement of cargo, managing dock workers, and ensuring that vessels are loaded and unloaded efficiently and safely. They work with shipping companies, customs officials, and logistics firms to keep goods flowing through the port.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 80_000, max: 150_000),
            educationLevel: .bachelors,
            icon: "building.2.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Harbor Pilot",
            category: "transportation",
            subcategory: "Maritime",
            description: "Harbor pilots are expert navigators who board large ships entering or leaving busy ports and guide them safely through narrow channels, strong currents, and congested waterways. They have deep local knowledge of water depth, tides, and port layout that large vessel captains may not possess.",
            pathway: nil,
            requiredInterests: ["transportation_logistics"],
            estimatedSalary: SalaryRange(min: 100_000, max: 200_000),
            educationLevel: .certification,
            icon: "helm",
            color: "#5D6D7E"
        ),

        // MARK: - Rail & Ground

        CareerPath(
            title: "Train Engineer",
            category: "transportation",
            subcategory: "Rail & Ground",
            description: "Train engineers operate locomotives on freight and passenger rail lines, controlling speed, applying brakes, and communicating with dispatchers to safely transport goods and people across the rail network. They follow precise schedules and safety protocols to prevent accidents on busy rail corridors.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "engineering_building"],
            estimatedSalary: SalaryRange(min: 65_000, max: 115_000),
            educationLevel: .vocational,
            icon: "train.side.front.car",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Railroad Conductor",
            category: "transportation",
            subcategory: "Rail & Ground",
            description: "Railroad conductors oversee the crew, passengers, and cargo on a train, coordinating operations between the engineer and station personnel to keep trains running on schedule. On freight trains they manage car inspections and switching operations, while on passenger trains they assist travelers and collect tickets.",
            pathway: nil,
            requiredInterests: ["transportation_logistics"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .vocational,
            icon: "tram.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Bus Driver",
            category: "transportation",
            subcategory: "Rail & Ground",
            description: "Bus drivers transport passengers on fixed routes in cities and towns, operating large vehicles safely while adhering to strict schedules and traffic laws. They assist passengers, collect fares, maintain safety on the bus, and play an important role in public transit systems that many people rely on daily.",
            pathway: nil,
            requiredInterests: ["transportation_logistics"],
            estimatedSalary: SalaryRange(min: 38_000, max: 70_000),
            educationLevel: .vocational,
            icon: "bus.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Truck Driver",
            category: "transportation",
            subcategory: "Rail & Ground",
            description: "Truck drivers haul freight across cities, states, and the country in large semi-trucks, keeping supply chains moving by delivering everything from food and medicine to machinery and consumer goods. They plan routes, perform vehicle inspections, and comply with federal regulations on hours of service and cargo handling.",
            pathway: nil,
            requiredInterests: ["transportation_logistics"],
            estimatedSalary: SalaryRange(min: 50_000, max: 90_000),
            educationLevel: .vocational,
            icon: "truck.box.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Delivery Driver",
            category: "transportation",
            subcategory: "Rail & Ground",
            description: "Delivery drivers transport packages, food, and goods directly to customers' homes and businesses, serving as the final link in e-commerce and retail supply chains. They navigate efficiently, manage delivery manifests, and provide customer service at each drop-off point.",
            pathway: nil,
            requiredInterests: ["transportation_logistics"],
            estimatedSalary: SalaryRange(min: 32_000, max: 60_000),
            educationLevel: .highSchool,
            icon: "shippingbox.fill",
            color: "#5D6D7E"
        ),

        // MARK: - Logistics & Warehousing

        CareerPath(
            title: "Logistics Manager",
            category: "transportation",
            subcategory: "Logistics & Warehousing",
            description: "Logistics managers plan and coordinate the movement of goods from suppliers to customers, overseeing transportation, warehousing, and inventory to keep supply chains running smoothly and cost-effectively. They manage carrier contracts, monitor shipments in real time, and solve problems when delays or disruptions occur.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 70_000, max: 130_000),
            educationLevel: .bachelors,
            icon: "arrow.triangle.branch",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Warehouse Manager",
            category: "transportation",
            subcategory: "Logistics & Warehousing",
            description: "Warehouse managers direct the daily operations of storage facilities where goods are received, organized, and shipped out, overseeing staff, inventory systems, and safety compliance. They optimize warehouse layout and processes to improve accuracy and speed while keeping costs under control.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 55_000, max: 100_000),
            educationLevel: .bachelors,
            icon: "building.2.crop.circle.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Supply Chain Analyst",
            category: "transportation",
            subcategory: "Logistics & Warehousing",
            description: "Supply chain analysts use data to evaluate and improve the flow of products from raw materials to finished goods, identifying inefficiencies and cost-saving opportunities across the entire supply chain. They build forecasting models, analyze supplier performance, and recommend strategies that help companies deliver products faster and cheaper.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "technology", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 60_000, max: 110_000),
            educationLevel: .bachelors,
            icon: "chart.line.uptrend.xyaxis.circle.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Freight Broker",
            category: "transportation",
            subcategory: "Logistics & Warehousing",
            description: "Freight brokers connect shippers who need to move goods with trucking companies and carriers that have available capacity, negotiating rates and arranging transportation on behalf of both parties. They track shipments, resolve issues in transit, and build relationships with a large network of carriers to find the best routes and prices.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 45_000, max: 100_000),
            educationLevel: .someCollege,
            icon: "person.2.wave.2.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Customs Broker",
            category: "transportation",
            subcategory: "Logistics & Warehousing",
            description: "Customs brokers are licensed professionals who help businesses import and export goods by preparing the legal documents required to clear shipments through customs and comply with international trade regulations. They stay current on tariffs, trade agreements, and government requirements to keep clients' goods moving across borders without costly delays.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship"],
            estimatedSalary: SalaryRange(min: 50_000, max: 95_000),
            educationLevel: .bachelors,
            icon: "doc.badge.checkmark.fill",
            color: "#5D6D7E"
        ),

        CareerPath(
            title: "Distribution Center Manager",
            category: "transportation",
            subcategory: "Logistics & Warehousing",
            description: "Distribution center managers run large fulfillment facilities where products are sorted, processed, and shipped out to stores or customers, managing hundreds of employees and complex automated systems. They set performance targets, ensure worker safety, and use technology and lean principles to maximize how quickly and accurately orders are fulfilled.",
            pathway: nil,
            requiredInterests: ["transportation_logistics", "business_entrepreneurship", "technology"],
            estimatedSalary: SalaryRange(min: 75_000, max: 135_000),
            educationLevel: .bachelors,
            icon: "building.columns.fill",
            color: "#5D6D7E"
        )
    ]
}
