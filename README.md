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
