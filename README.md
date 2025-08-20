# Tangible Modification Intervention (TMI) App

### Aligning Student Interests & Hobbies with Academic Success

The TMI App is a comprehensive platform designed to support the Tangible Modification Intervention program. It provides tools for educators to connect with students, understand their interests, and create personalized educational plans that foster engagement and positive behavioral outcomes. This repository contains the source code for the TMI mobile application, built for the Apple ecosystem.

## Core Functionality

-   **Cross-Platform Compatibility**: Seamless access on teacher and student devices (iOS, iPadOS, macOS).
-   **Interest & Hobby Assessment**: Digital questionnaires and surveys to capture student interests.
-   **Personalized Career Educational Plans**: Auto-generated plans based on student responses to align hobbies with academic and career pathways.
-   **Tiered Intervention Support**: Specifically designed to support students in Tier 1 and Tier 2 intervention categories.
-   **Real-Time Data Synchronization**: Keeps student and educator interfaces instantly updated.
-   **Resource Recommendation Engine**: Automatically matches student interests to relevant career paths and learning materials.

## Target Deployment

-   **Educational Levels**: Elementary through university-level institutions.
-   **User Roles**: Supports multiple user roles, including students, teachers, counselors, administrators, and parents.
-   **Compliance**: Designed for COPPA/FERPA compliant data handling in educational environments.

## Technical Architecture

-   **Design Pattern**: Utilizes the **MVVM (Model-View-ViewModel)** pattern for a clean and scalable architecture.
-   **UI Framework**: Built with **SwiftUI** for a modern, responsive, and declarative user interface across Apple platforms.
-   **Backend & Database**: Integrated with **Firebase** for core services, including:
    -   Firebase Authentication for secure user login.
    -   Firestore for a real-time, scalable database.
    -   Cloud Storage for file and media storage.
-   **Offline-First**: Implements local caching and data synchronization for a robust offline experience.
-   **Access Control**: Features role-based access control (RBAC) to ensure users can only access appropriate data.

## Key Components

-   **Student Interface**: Features onboarding surveys, a personalized dashboard, activity tracking, and progress visualization.
-   **Educator Interface**: Includes tools for student management, TMI plan creation, an analytics dashboard, and intervention assignments.
-   **Assessment Engine**: A dynamic questionnaire system with branching logic and automatic scoring.
-   **Intervention Models**: Contains six specialized modules to address different student needs and behavioral patterns.

## Technology Stack

-   **Language**: Swift
-   **Framework**: SwiftUI
-   **Backend**: Firebase (Authentication, Firestore, Cloud Storage)
-   **Platforms**: iOS, iPadOS, macOS

## Example Workflows

### Staff Flow (Teacher/Counselor)

1.  **Student Identification**: An educator identifies a student showing behavioral concerns or academic disengagement.
2.  **Assessment Assignment**: The educator assigns the initial TMI survey through their dashboard.
3.  **Results Review**: The educator reviews the student's interest/hobby profile and system-generated intervention recommendations.
4.  **Model Selection**: The educator chooses the most appropriate TMI model (e.g., "Align Your Mind" for focus issues).
5.  **Plan Creation**: Guided wizards help set goals, assign activities, and configure progress metrics.
6.  **Resource Allocation**: The system automatically suggests relevant materials based on student interests (e.g., podcasting resources for a student interested in media).
7.  **Progress Monitoring**: The educator tracks student engagement and behavioral changes through real-time analytics.
8.  **Collaboration**: The educator coordinates with social workers and other staff via integrated messaging and notes.

### Student Experience

1.  **Onboarding**: The student creates an account and completes a comprehensive interest/hobby survey with adaptive questioning.
2.  **Profile Creation**: The system analyzes responses and identifies the student's primary interest areas.
3.  **Plan Presentation**: The student receives a personalized Yearly TMI Plan with clear goals and milestones.
4.  **Model Assignment**: The student engages with their specific intervention model. For example, a student interested in podcasting in the "Chase Your Space" model receives learning modules on audio production, communication skills activities, and sees connections to careers in broadcast journalism or marketing.
5.  **Daily Engagement**: The student accesses a personalized activity feed with interest-based learning materials.
6.  **Progress Tracking**: The student completes activities and sees visual progress toward their goals.
7.  **Ongoing Assessment**: The student participates in periodic check-ins to refine and adjust their intervention approach.

## The Six Intervention Models

1.  **Chase Your Space**: Cultivates a career pathway for students who already have a clear direction.
2.  **Acknowledge Your Interests**: Provides individual support to validate and integrate student interests into their academic life.
3.  **Align Your Mind**: Helps students with focus and task management for better academic alignment.
4.  **Direct & Correct**: Offers behavioral support through collaboration with school social workers and coping skills development.
5.  **From Bully 2 Boss**: Fosters leadership development to redirect negative behaviors into positive, constructive actions.
6.  **From Meek & Passive 2 Promising Protector**: Builds confidence and empowers introverted students in social interactions.

## Expected Outcomes

-   Increased student engagement through personalized, interest-based learning.
-   Improved behavioral outcomes for Tier 1 and Tier 2 intervention students.
-   Enhanced teacher effectiveness via data-driven intervention strategies.
-   Stronger connections between student interests and academic achievement.
-   A comprehensive support system that bridges education and career development.

## Getting Started

This project is intended for developers contributing to the TMI app.

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    ```
2.  **Install Dependencies:** This project uses Swift Package Manager. Dependencies should resolve automatically when you open the project in Xcode.
3.  **Firebase Setup:** You will need to set up your own Firebase project and add the `GoogleService-Info.plist` file to the `TMI/` directory. Ensure the bundle ID in your Xcode project matches the one in your Firebase project settings.

## Contributing

We welcome contributions to the TMI App! If you'd like to contribute, please follow these steps:

1.  Fork the repository.
2.  Create a new branch for your feature or bug fix: `git checkout -b feature/your-feature-name`
3.  Make your changes and commit them with a clear message.
4.  Push your branch to your fork.
5.  Create a pull request to the `main` branch of this repository.

Please ensure your code adheres to the project's coding style and conventions. We appreciate your help in making this tool better for students and educators!



# Tangible Modification Intervention (TMI) App
*Aligning Student Interests & Hobbies with Academic Success Through Trauma-Informed Support*

## Application Needs

### Core Functionality
- **Cross-platform compatibility** for seamless access on teacher and student devices across all educational settings
- **Comprehensive assessment system** including interest/hobby surveys and trauma-informed questionnaires addressing parental incarceration
- **Personalized Career Educational Plan generation** based on student responses and individual circumstances
- **Tiered intervention support** for students in Tier 1 and Tier 2 categories, with specialized modules for trauma-affected students
- **Real-time data synchronization** between student and educator interfaces with secure, confidential data handling
- **Resource recommendation engine** that automatically matches interests to career pathways while considering individual challenges and support needs

### Target Deployment
- Elementary through university-level institutions
- Support for multiple user roles: students, teachers, counselors, administrators, social workers, and legal guardians
- COPPA/FERPA compliant data handling with enhanced privacy protections for sensitive family information

## Design Overview

### Architecture
- **MVVM Pattern** with SwiftUI for modern, responsive interfaces
- **Firebase Integration** for authentication, real-time database, and cloud storage with enhanced security protocols
- **Offline-first approach** with local caching and sync capabilities for consistent access
- **Role-based access control** ensuring appropriate data visibility and confidentiality protection
- **Trauma-informed design principles** throughout the user interface and interaction patterns

### Key Components
1. **Student Interface**: Comprehensive onboarding surveys, personalized dashboards, activity tracking, progress visualization, and confidential support resources
2. **Educator Interface**: Student management, plan creation tools, analytics dashboard, intervention assignment, and trauma-informed case notes
3. **Assessment Engine**: Dynamic questionnaire system with branching logic, automatic scoring, and specialized modules for students with incarcerated parents
4. **Intervention Models**: Six core specialized modules plus integrated trauma support addressing different student needs and behavioral patterns
5. **Parental Incarceration Support Module**: Dedicated component for students affected by parental incarceration

## Staff Flow Example

### Teacher/Counselor Workflow
1. **Student Identification**: Teacher identifies a student showing behavioral concerns, academic disengagement, or signs of family-related stress
2. **Comprehensive Assessment**: Assigns TMI survey package including interest assessment and, when appropriate, trauma-informed questionnaires
3. **Confidential Results Review**: Reviews student's complete profile including interests, family circumstances, and trauma indicators with appropriate privacy protections
4. **Model Selection**: Chooses appropriate TMI model while considering trauma-informed approaches (e.g., "Align Your Mind" with trauma adaptations, specialized "Direct & Correct" for students with incarcerated parents)
5. **Collaborative Plan Creation**: Works with social workers and counselors to create comprehensive support plans addressing both academic and emotional needs
6. **Resource Allocation**: System provides trauma-informed resources alongside interest-based materials (e.g., journaling activities for a writing-interested student dealing with parental incarceration)
7. **Progress Monitoring**: Tracks academic progress, behavioral changes, and emotional well-being through specialized analytics
8. **Support Network Coordination**: Facilitates communication between educators, social workers, legal guardians, and appropriate family members

## User Flow Example

### Student Experience
1. **Onboarding**: Creates account and completes comprehensive assessment in a safe, supportive environment
   - Interest and hobby exploration questionnaire
   - Confidential family circumstances assessment (when applicable)
   - Learning preferences and support needs evaluation
2. **Profile Creation**: System analyzes all responses to create a holistic student profile respecting privacy and sensitivity
3. **Personalized Plan Presentation**: Receives tailored Yearly TMI Plan addressing both interests and individual circumstances
4. **Model Assignment with Trauma-Informed Support**: Engages with intervention model adapted to personal needs:
   - **Example - Student with incarcerated parent interested in podcasting**:
     - Audio production learning modules with flexible scheduling for family visits
     - Communication skills development including healthy expression of emotions
     - Academic connections emphasizing stability and future planning
     - Specialized counseling resources and peer support access
     - Career pathway visualization showing achievable goals despite current challenges
5. **Daily Engagement**: Accesses personalized content that acknowledges their full experience while building on their strengths
6. **Confidential Progress Tracking**: Monitors both academic and emotional growth with appropriate privacy protections
7. **Ongoing Support**: Regular check-ins that address changing family circumstances and evolving needs

## Seven Intervention Models

### Core Models
1. **Chase Your Space**: Career pathway cultivation for students with clear aspirations
2. **Acknowledge Your Interests**: Individual support to validate and integrate student interests
3. **Align Your Mind**: Focus and task management for students needing academic alignment
4. **Direct & Correct**: Behavioral support through social worker collaboration and trauma-informed coping skills
5. **From Bully 2 Boss**: Leadership development to redirect negative behaviors positively
6. **From Meek & Passive 2 Promising Protector**: Confidence building for introverted students

### Specialized Support Module
7. **Parental Incarceration Support**: Comprehensive trauma-informed intervention addressing:
   - Assessment of family circumstances and living arrangements
   - Academic accommodation strategies for unique challenges
   - Emotional support and coping skill development
   - Connection to specialized resources and peer support
   - Integration with existing models for holistic support

## Assessment Framework

### Parental Incarceration Component
- **Confidential screening** to identify affected students
- **Comprehensive evaluation** including:
  - Which parent is incarcerated and family structure
  - Contact frequency and relationship maintenance
  - Age at time of incarceration and developmental impact
  - Effects on schooling, daily living, and social relationships
  - Current living arrangements and legal guardian support
- **Trauma-informed response planning** with appropriate professional involvement

## Expected Outcomes
- **Increased student engagement** through personalized, interest-based learning that acknowledges individual circumstances
- **Improved behavioral and academic outcomes** for Tier 1 and Tier 2 intervention students, including those affected by family trauma
- **Enhanced educator effectiveness** through comprehensive, trauma-informed intervention strategies
- **Stronger support networks** connecting interests, academics, and emotional well-being
- **Comprehensive trauma-informed care** that addresses the unique needs of students with incarcerated parents
- **Improved long-term outcomes** through early identification and intervention for at-risk students
- **Strengthened family connections** where appropriate and beneficial for student success









(OLD)

# **Tangible Modification Intervention (TMI) App: Development Breakdown**

## **1\. Architecture Overview**

The TMI application will follow the MVVM (Model-View-ViewModel) architecture pattern, which works exceptionally well with SwiftUI's declarative approach:

* **Models**: Core data structures representing students, questionnaires, surveys, and intervention plans  
* **Views**: SwiftUI interfaces for different user journeys  
* **ViewModels**: Intermediary components that manage state, business logic, and Firebase interactions

The app will leverage the new Swift observation system with `@Observable` macro for the ViewModels, allowing for efficient UI updates when data changes:

swift  
@Observable class SurveyViewModel {  
    *// Properties and methods*

}

## **2\. Data Model Design**

### **Core Entities**

1. **Student**  
   * Personal information  
   * Academic records  
   * Behavior indicators (tier classifications)  
   * Assigned intervention models  
   * Survey response history  
2. **Survey**  
   * Questions categorized by interest domains  
   * Response formats (multiple choice, rating scales)  
   * Scoring algorithms  
   * Associated intervention pathways  
3. **TMI Plan**  
   * Yearly goals  
   * Selected intervention models  
   * Progress metrics  
   * Milestone achievements  
   * Notes from educators/counselors  
4. **Activity**  
   * Interest-based activities tailored to each model  
   * Resources and materials  
   * Completion tracking  
   * Student engagement metrics

## **3\. Firebase Integration**

### **Authentication**

* Multi-role authentication system using Firebase Auth:  
  * Student accounts  
  * Teacher/counselor accounts  
  * Administrator accounts  
  * Parent/guardian limited access

### **Cloud Firestore**

* Database structure with collections for:  
  * Students  
  * Surveys  
  * Intervention plans  
  * Activities  
  * Progress reports  
* Real-time data synchronization using Firebase listeners:

swift  
func observeStudentData(studentID: String) {  
    *// Implement Firestore listener that updates the @Observable ViewModel*

}

### **Firebase Storage**

* Storage for multimedia resources:  
  * Activity materials  
  * Student-uploaded content  
  * Progress documentation

### **Firebase Analytics**

* Track student engagement  
* Measure intervention effectiveness  
* Identify usage patterns for iterative improvement

## **4\. User Interface Architecture**

### **Student Experience**

* **Onboarding Flow**  
  * Account creation  
  * Initial survey completion  
  * Interest selection interface  
  * Dashboard introduction  
* **Dashboard**  
  * Personalized activity feed  
  * Progress visualization  
  * TMI plan overview  
  * Upcoming tasks/activities  
* **Survey Interface**  
  * Engaging, age-appropriate question presentation  
  * Dynamic question sequencing based on previous answers  
  * Progress indicators  
  * Save and resume functionality  
* **Model-Specific Modules** (6 models as described in requirements)  
  * Each with unique UI elements and interactions tailored to the intervention approach  
  * Gamification elements to increase engagement

### **Educator Interface**

* **Student Management**  
  * List/grid views with filtering capabilities  
  * Progress monitoring  
  * Intervention assignment  
  * Meeting scheduling  
* **Plan Creation Tools**  
  * Model selection interface  
  * Goal setting wizards  
  * Activity assignment  
  * Progress metric configuration  
* **Analytics Dashboard**  
  * Behavioral trend visualization  
  * Intervention effectiveness metrics  
  * Engagement statistics  
  * Export capabilities for reporting

## **5\. SwiftUI Implementation Considerations**

### **State Management**

* Use `@Observable` macro for complex ViewModels:  
  * Cleaner data flow compared to older `ObservableObject` pattern  
  * Automatic dependency tracking for views  
* Use `@State` for view-local temporary state:  
  * Form inputs  
  * UI controls  
  * Animation states  
* Use `@Query` for Firestore data (if using FirebaseFirestoreSwift package):  
  * Declarative data fetching  
  * Automatic UI updates

### **Navigation Architecture**

* Implement with SwiftUI's new navigation APIs:  
  * `NavigationStack` for hierarchical navigation  
  * `NavigationSplitView` for master-detail interfaces on iPadOS  
  * Programmatic navigation using path-based approach

swift  
NavigationStack(path: $viewModel.navigationPath) {  
    *// Content*  
    .navigationDestination(for: NavigationDestination.self) { destination in  
        switch destination {  
        case .surveyDetail(let id):  
            SurveyDetailView(surveyID: id)  
        *// Other destinations*  
        }  
    }

}

### **Responsive Design**

* Use SwiftUI layout system to adapt to different device sizes:  
  * Grid layouts with adaptive columns  
  * Dynamic type support  
  * Device orientation changes  
* Implement iPad-specific layouts for educator interfaces:  
  * Multi-column layouts  
  * Sidebar navigation  
  * Expanded detail views

## **6\. Core Features Implementation**

### **Questionnaire Engine**

* Dynamic survey system:  
  * Question branching logic  
  * Response validation  
  * Progress tracking  
  * Results analysis  
* Implement using a combination of:  
  * SwiftUI form components  
  * Custom input elements  
  * Animations for transitions

### **TMI Plan Generator**

* Algorithm for matching survey results to intervention models  
* Plan visualization with milestone tracking  
* Adjustment mechanisms for educators

### **Activity Recommendation System**

* Interest-based activity suggestions  
* Personalized content delivery  
* Engagement tracking  
* Feedback collection

### **Social Worker Integration**

* Secure messaging system  
* Session notes and tracking  
* Resource sharing  
* Progress reporting

## **7\. Offline Capabilities**

* Implement offline-first approach:  
  * Cache survey data locally  
  * Queue changes for sync when online  
  * Background synchronization  
  * Conflict resolution

swift  
*// Using Firebase offline persistence*  
let settings \= FirestoreSettings()  
settings.isPersistenceEnabled \= true  
let db \= Firestore.firestore()

db.settings \= settings

## **8\. Security and Privacy**

* Data encryption at rest and in transit  
* Role-based access control  
* Audit logging for sensitive operations  
* COPPA/FERPA compliance measures  
* Data retention policies

## **9\. Development Workflow**

### **Environment Setup**

* Development environment:  
  * Xcode 15+ (for modern Swift features)  
  * Firebase iOS SDK integration  
  * SwiftUI Preview providers for rapid UI iteration  
* Testing infrastructure:  
  * XCTest for unit testing  
  * UI testing with XCUITest  
  * Firebase Test Lab for device testing

### **CI/CD Pipeline**

* GitHub Actions or Bitbucket Pipelines for:  
  * Automated testing  
  * Code quality checks  
  * Beta deployments via TestFlight  
  * Production releases

## **10\. Model-Specific Implementation Details**

### **Model 1: Chase Your Space**

* Career pathway visualization  
* Skill mapping to academic subjects  
* Mentor connection features  
* Progress tracking toward career goals

### **Model 2: Acknowledge Your Interests**

* Interest discovery tools  
* Hobby-to-skill mapping  
* Resource recommendation engine  
* Academic connection visualizations

### **Model 3: Align Your Mind**

* Focus tracking features  
* Task management tools  
* Goal alignment visualization  
* Progress monitoring

### **Model 4: Direct & Correct**

* Coping skills library  
* Mood tracking  
* Scenario-based learning  
* Connection to social worker interface

### **Model 5: From Bully 2 Boss**

* Leadership skill development  
* Empathy-building activities  
* Positive reinforcement system  
* Behavior tracking and reflection

### **Model 6: From Meek & Passive 2 Promising**

* Social skill development modules  
* Confidence-building activities  
* Gradual exposure challenges  
* Self-reflection tools

## **11\. Analytics and Reporting**

* Implement custom Firebase Analytics events for:  
  * Intervention effectiveness tracking  
  * Engagement metrics  
  * Behavioral change indicators  
  * Academic correlation analysis  
* Generate automated reports for:  
  * Individual student progress  
  * Group trend analysis  
  * Intervention effectiveness  
  * Resource utilization

## **12\. Future Extensibility**

* Design for extensibility:  
  * Modular architecture for adding new intervention models  
  * Plugin system for additional assessments  
  * API planning for potential integration with school information systems  
  * Localization framework for multiple language support

This comprehensive breakdown provides a foundation for developing the TMI application using modern SwiftUI practices and Firebase integration. The app's architecture leverages the latest Swift features like `@Observable` for efficient state management while providing a robust framework for implementing the six intervention models described in the requirements.

