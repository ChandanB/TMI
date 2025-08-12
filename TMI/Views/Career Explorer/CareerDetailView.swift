//
//  CareerDetailView.swift
//  TMI
//
//  Created by Chandan Brown on 4/21/25.
//

import SwiftUI

struct CareerDetailView: View {
  let career: Career
  @State private var selectedTab = 0
  @State private var isShowingRelatedCareers = false
  @State private var animateContent = false
  @State private var showSchoolFinder = false
  @State private var relatedCareers: [Career] = []
  @State private var isBookmarked = false
  @State private var isLoading = false
  @State private var error: Error?
  @Environment(\.presentationMode) var presentationMode

  private let careerService = CareerService.shared

  // Sample progress data - in a real app, this would come from user data
  private let progressData: [(String, Double)] = [
    ("Core Knowledge", 0.75),
    ("Experience", 0.35),
    ("Skills Mastery", 0.60),
    ("Education", 0.45),
  ]

  var body: some View {
    ZStack {
      // Background gradient
      LinearGradient(
        gradient: Gradient(colors: [
          Color.tmiBackground,
          Color.tmiPrimary.opacity(0.1),
          Color.tmiBackground,
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 0) {
          // Hero header
          heroHeader

          // Tab selection
          tabSelector

          // Main content container with glass morphism effect
          ZStack {
            RoundedRectangle(cornerRadius: 30)
              .fill(Color.white.opacity(0.85))
              .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -5)

            // Content based on selected tab
            VStack {
              TabView(selection: $selectedTab) {
                overviewTab.tag(0)
                skillsTab.tag(1)
                educationTab.tag(2)
                pathwayTab.tag(3)
              }
              .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

              // Related careers section
              if !relatedCareers.isEmpty {
                relatedCareersSection
                  .opacity(animateContent ? 1 : 0)
                  .offset(y: animateContent ? 0 : 20)
                  .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: animateContent)
              }
            }
            .padding(.top, 20)
          }
        }
        .ignoresSafeArea(edges: .bottom)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text(career.title)
            .font(.headline)
            .foregroundColor(.tmiPrimary)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            Task {
              await toggleBookmark()
            }
          }) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
              .foregroundColor(.tmiPrimary)
          }
        }
      }
    }
    .task {
      await loadCareerData()
    }
    .onAppear {
      withAnimation(.easeOut(duration: 0.6)) {
        animateContent = true
      }
      
      // Track career view
      Task {
        try? await careerService.trackCareerExploration(career: career, action: .viewed)
      }
    }
    .sheet(isPresented: $showSchoolFinder) {
      SchoolFinderView(careerField: career.field)
    }
  }

  // MARK: - Hero Header
  private var heroHeader: some View {
    ZStack(alignment: .bottom) {
      // Background image with overlay
      ZStack {
        Image(systemName: getCareerIcon(field: career.field))
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 120, height: 120)
          .foregroundColor(.tmiPrimary.opacity(0.15))
          .offset(x: 40, y: -20)
          .rotationEffect(.degrees(15))

        // Animated particles for visual interest
        ForEach(0..<5) { i in
          Circle()
            .fill(Color.tmiSecondary.opacity(0.2))
            .frame(width: CGFloat.random(in: 5...15))
            .offset(
              x: CGFloat.random(in: -80...80),
              y: CGFloat.random(in: -40...20)
            )
            .opacity(animateContent ? 1 : 0)
            .animation(
              Animation.easeInOut(duration: Double.random(in: 2...4))
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...2)),
              value: animateContent
            )
        }
      }

      // Career info overlay
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(career.title)
              .font(.title)
              .fontWeight(.bold)
              .foregroundColor(.white)
              .opacity(animateContent ? 1 : 0)
              .offset(y: animateContent ? 0 : 20)
              .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)

            Text(career.field)
              .font(.title3)
              .foregroundColor(.white.opacity(0.8))
              .opacity(animateContent ? 1 : 0)
              .offset(y: animateContent ? 0 : 20)
              .animation(
                .spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
          }

          Spacer()

          // Career icon
          ZStack {
            Circle()
              .fill(Color.white.opacity(0.2))
              .frame(width: 56, height: 56)

            Image(systemName: getCareerIcon(field: career.field))
              .font(.system(size: 26))
              .foregroundColor(.white)
          }
          .opacity(animateContent ? 1 : 0)
          .scaleEffect(animateContent ? 1 : 0.6)
          .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: animateContent)
        }

        // Career quick stats
        HStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("$\(career.salaryRange.lowerBound/1000)k-$\(career.salaryRange.upperBound/1000)k")
              .font(.headline)
              .foregroundColor(.white)

            Text("Salary Range")
              .font(.caption)
              .foregroundColor(.white.opacity(0.7))
          }

          Divider()
            .frame(height: 24)
            .background(Color.white.opacity(0.3))

          VStack(alignment: .leading, spacing: 4) {
            Text(getGrowthCategory(outlook: career.jobOutlook))
              .font(.headline)
              .foregroundColor(.white)

            Text("Job Growth")
              .font(.caption)
              .foregroundColor(.white.opacity(0.7))
          }

          Divider()
            .frame(height: 24)
            .background(Color.white.opacity(0.3))

          VStack(alignment: .leading, spacing: 4) {
            Text(getEducationLevel(education: career.education))
              .font(.headline)
              .foregroundColor(.white)

            Text("Education")
              .font(.caption)
              .foregroundColor(.white.opacity(0.7))
          }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(Color.tmiPrimary.opacity(0.8))
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .opacity(animateContent ? 1 : 0)
        .offset(y: animateContent ? 0 : 30)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 16)
    }
    .frame(height: 240)
    .background(
      LinearGradient(
        gradient: Gradient(colors: [
          Color.tmiPrimary.opacity(0.8),
          Color.tmiPrimary,
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
  }

  // MARK: - Tab Selector
  private var tabSelector: some View {
    HStack(spacing: 0) {
      ForEach(["Overview", "Skills", "Education", "Pathway"], id: \.self) { tab in
        let index = ["Overview", "Skills", "Education", "Pathway"].firstIndex(of: tab) ?? 0

        Button(action: {
          withAnimation {
            selectedTab = index
          }
        }) {
          VStack(spacing: 8) {
            Text(tab)
              .font(.subheadline)
              .fontWeight(selectedTab == index ? .semibold : .regular)
              .foregroundColor(selectedTab == index ? .tmiPrimary : .gray)

            // Indicator for the selected tab
            Rectangle()
              .fill(selectedTab == index ? Color.tmiPrimary : Color.clear)
              .frame(height: 3)
              .cornerRadius(2)
          }
        }
        .frame(maxWidth: .infinity)
      }
    }
    .padding(.vertical, 8)
    .background(Color.white)
    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
  }

  // MARK: - Overview Tab
  private var overviewTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      // About section
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "About This Career", icon: "info.circle")

        Text(career.description)
          .font(.body)
          .foregroundColor(.tmiText)
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(4)
          .padding(.bottom, 4)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )

      // Job outlook section
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Job Outlook", icon: "chart.line.uptrend.xyaxis")

        Text(career.jobOutlook)
          .font(.body)
          .foregroundColor(.tmiText)
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(4)

        // Growth indicator
        HStack {
          Text("Growth Potential:")
            .font(.subheadline)
            .foregroundColor(.gray)

          ForEach(0..<5) { i in
            Image(systemName: "star.fill")
              .foregroundColor(
                i < getGrowthRating(outlook: career.jobOutlook) ? .yellow : .gray.opacity(0.3))
          }
        }
        .padding(.top, 8)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )

      // Your progress section
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Your Progress", icon: "chart.bar.fill")

        ForEach(progressData, id: \.0) { item in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text(item.0)
                .font(.subheadline)
                .foregroundColor(.tmiText)

              Spacer()

              Text("\(Int(item.1 * 100))%")
                .font(.caption)
                .foregroundColor(.tmiSecondary)
            }

            // Progress bar
            ZStack(alignment: .leading) {
              RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(height: 8)

              RoundedRectangle(cornerRadius: 4)
                .fill(getProgressColor(value: item.1))
                .frame(width: CGFloat(item.1) * UIScreen.main.bounds.width * 0.8, height: 8)
                .animation(
                  .spring(response: 0.6, dampingFraction: 0.8).delay(0.3), value: animateContent)
            }
          }
        }

        Button(action: {
          // Action to create personalized plan
        }) {
          Text("Create Personalized Plan")
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiPrimary)
            )
        }
        .padding(.top, 16)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Skills Tab
  private var skillsTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Core skills section
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Required Skills", icon: "star.fill")

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
          ForEach(career.skills, id: \.self) { skill in
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.subheadline)

              Text(skill)
                .font(.subheadline)
                .foregroundColor(.tmiText)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
              RoundedRectangle(cornerRadius: 8)
                .fill(Color.tmiSecondary.opacity(0.1))
            )
          }
        }

        Divider()
          .padding(.vertical, 12)

        // Skill development section
        sectionHeader(title: "Skill Development Resources", icon: "book.fill")

        ForEach(getSkillResources(), id: \.name) { resource in
          HStack(spacing: 12) {
            ZStack {
              RoundedRectangle(cornerRadius: 8)
                .fill(resource.color.opacity(0.15))
                .frame(width: 40, height: 40)

              Image(systemName: resource.icon)
                .foregroundColor(resource.color)
                .font(.system(size: 20))
            }

            VStack(alignment: .leading, spacing: 4) {
              Text(resource.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.tmiText)

              Text(resource.description)
                .font(.caption)
                .foregroundColor(.tmiSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
              .foregroundColor(.gray)
              .font(.caption)
          }
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white)
              .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
          )
          .padding(.vertical, 4)
        }
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )

      // Personality fit section
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Personality Fit", icon: "person.fill")

        HStack(spacing: 16) {
          ForEach(getPersonalityTraits(), id: \.trait) { trait in
            VStack(spacing: 8) {
              ZStack {
                Circle()
                  .fill(Color.tmiPrimary.opacity(0.1))
                  .frame(width: 64, height: 64)

                VStack(spacing: 2) {
                  Text(trait.score)
                    .font(.headline)
                    .foregroundColor(.tmiPrimary)

                  Text(trait.label)
                    .font(.caption2)
                    .foregroundColor(.tmiSecondary)
                }
              }

              Text(trait.trait)
                .font(.caption)
                .foregroundColor(.tmiText)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
          }
        }

        Button(action: {
          // Track skills exploration
          Task {
            try? await careerService.trackCareerExploration(career: career, action: .exploredSkills)
          }
          // Action to take personality assessment
        }) {
          HStack {
            Image(systemName: "doc.text.fill")
            Text("Take Full Assessment")
          }
          .font(.subheadline)
          .foregroundColor(.tmiPrimary)
          .padding(.vertical, 12)
          .padding(.horizontal, 16)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.tmiPrimary, lineWidth: 1)
          )
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 16)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Education Tab
  private var educationTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Required education
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Required Education", icon: "graduationcap.fill")

        Text(career.education)
          .font(.body)
          .foregroundColor(.tmiText)
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(4)

        // Education path visual
        VStack(spacing: 0) {
          ForEach(getEducationPath(), id: \.level) { path in
            HStack(alignment: .top, spacing: 16) {
              // Timeline indicator
              VStack(spacing: 0) {
                Circle()
                  .fill(path.isRequired ? Color.tmiPrimary : Color.gray.opacity(0.3))
                  .frame(width: 16, height: 16)

                if path.level != getEducationPath().last?.level {
                  Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2, height: 50)
                }
              }

              VStack(alignment: .leading, spacing: 6) {
                Text(path.level)
                  .font(.headline)
                  .foregroundColor(path.isRequired ? .tmiPrimary : .tmiText)

                Text(path.description)
                  .font(.subheadline)
                  .foregroundColor(.tmiSecondary)
                  .fixedSize(horizontal: false, vertical: true)

                HStack {
                  Image(systemName: path.icon)
                  Text(path.timeline)
                }
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 4)
              }
              .padding(.bottom, 24)
            }
          }
        }
        .padding(.vertical, 16)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )

      // Recommended programs
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Recommended Programs", icon: "building.columns.fill")

        VStack(spacing: 16) {
          ForEach(getRecommendedPrograms(), id: \.name) { program in
            HStack(spacing: 16) {
              // School logo placeholder
              ZStack {
                RoundedRectangle(cornerRadius: 8)
                  .fill(Color.gray.opacity(0.1))
                  .frame(width: 60, height: 60)

                Text(program.initials)
                  .font(.system(size: 20, weight: .bold))
                  .foregroundColor(.tmiPrimary)
              }

              VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                  .font(.headline)
                  .foregroundColor(.tmiText)

                Text(program.institution)
                  .font(.subheadline)
                  .foregroundColor(.tmiSecondary)

                HStack {
                  Label(program.duration, systemImage: "clock")
                  Spacer()
                  Label(
                    program.format,
                    systemImage: program.format.contains("Online") ? "network" : "building.2")
                }
                .font(.caption)
                .foregroundColor(.gray)
              }
            }
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
            )
          }
        }

        Button(action: {
          showSchoolFinder = true
          
          // Track education exploration
          Task {
            try? await careerService.trackCareerExploration(career: career, action: .exploredEducation)
          }
        }) {
          Text("Find More Schools")
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiPrimary)
            )
        }
        .padding(.top, 16)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Career Pathway Tab
  private var pathwayTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Career pathway visualization
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Career Progression", icon: "arrow.up.right")
          .onAppear {
            // Track pathway exploration
            Task {
              try? await careerService.trackCareerExploration(career: career, action: .exploredPathway)
            }
          }

        // Career path visualization
        VStack(spacing: 0) {
          ForEach(getCareerPath(), id: \.title) { path in
            VStack(spacing: 0) {
              HStack(alignment: .top, spacing: 16) {
                // Level indicator
                VStack(spacing: 0) {
                  ZStack {
                    Circle()
                      .fill(Color.tmiPrimary.opacity(path.isCurrent ? 1.0 : 0.3))
                      .frame(width: 24, height: 24)

                    if path.isCurrent {
                      Circle()
                        .stroke(Color.tmiPrimary, lineWidth: 2)
                        .frame(width: 32, height: 32)
                    }
                  }

                  if path.title != getCareerPath().last?.title {
                    Rectangle()
                      .fill(Color.tmiPrimary.opacity(0.3))
                      .frame(width: 2, height: 50)
                  }
                }

                VStack(alignment: .leading, spacing: 8) {
                  Text(path.title)
                    .font(.headline)
                    .foregroundColor(path.isCurrent ? .tmiPrimary : .tmiText)

                  Text(path.description)
                    .font(.subheadline)
                    .foregroundColor(.tmiSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                  HStack {
                    Text("$\(path.salary)/year")
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Color.tmiSecondary.opacity(0.1))
                      .cornerRadius(4)

                    Spacer()

                    Text("\(path.yearsExperience) years")
                      .padding(.horizontal, 8)
                      .padding(.vertical, 4)
                      .background(Color.tmiSecondary.opacity(0.1))
                      .cornerRadius(4)
                  }
                  .font(.caption)
                  .foregroundColor(.tmiSecondary)
                }
                .padding(.bottom, 24)
              }
            }
          }
        }
        .padding(.top, 8)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )

      // Milestones and achievements
      VStack(alignment: .leading, spacing: 12) {
        sectionHeader(title: "Key Milestones", icon: "flag.fill")

        ForEach(getMilestones(), id: \.title) { milestone in
          HStack(spacing: 16) {
            ZStack {
              Circle()
                .fill(milestone.color.opacity(0.2))
                .frame(width: 48, height: 48)

              Image(systemName: milestone.icon)
                .font(.system(size: 20))
                .foregroundColor(milestone.color)
            }

            VStack(alignment: .leading, spacing: 4) {
              Text(milestone.title)
                .font(.headline)
                .foregroundColor(.tmiText)

              Text(milestone.description)
                .font(.subheadline)
                .foregroundColor(.tmiSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          .padding(12)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.white)
              .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 2)
          )
          .padding(.bottom, 8)
        }

        Button(action: {
          // Action to create career roadmap
        }) {
          Text("Create Your Career Roadmap")
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.tmiPrimary)
            )
        }
        .padding(.top, 8)
      }
      .padding(20)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color.white)
          .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
      )
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Related Careers Section
  private var relatedCareersSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Related Careers")
          .font(.headline)
          .foregroundColor(.tmiPrimary)

        Spacer()

        Button(action: {
          isShowingRelatedCareers.toggle()
          
          // Track related careers exploration
          if isShowingRelatedCareers {
            Task {
              try? await careerService.trackCareerExploration(career: career, action: .searchedRelated)
            }
          }
        }) {
          Text(isShowingRelatedCareers ? "Show Less" : "View All")
            .font(.subheadline)
            .foregroundColor(.tmiSecondary)
        }
      }
      .padding(.horizontal, 20)

      if isShowingRelatedCareers {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(relatedCareers) { career in
              NavigationLink(destination: CareerDetailView(career: career)) {
                RelatedCareerCard(career: career)
              }
              .buttonStyle(PlainButtonStyle())
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 20)
        }
      }
    }
    .padding(.top, 24)
  }

  // MARK: - Helper Components
  private func sectionHeader(title: String, icon: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: icon)
        .foregroundColor(.tmiPrimary)
        .font(.headline)

      Text(title)
        .font(.title3)
        .fontWeight(.bold)
        .foregroundColor(.tmiPrimary)
    }
  }

  // MARK: - Helper Functions
  private func getCareerIcon(field: String) -> String {
    switch field {
    case "Technology": return "desktopcomputer"
    case "Healthcare": return "heart.text.square"
    case "Education": return "book"
    case "Business": return "briefcase"
    case "Engineering": return "gearshape.2"
    case "Arts": return "paintpalette"
    case "Science": return "atom"
    default: return "star"
    }
  }

  private func getGrowthCategory(outlook: String) -> String {
    if outlook.contains("rapid") || outlook.contains("fast") {
      return "High Growth"
    } else if outlook.contains("steady") || outlook.contains("stable") {
      return "Stable"
    } else if outlook.contains("decline") || outlook.contains("slow") {
      return "Limited"
    } else {
      return "Moderate"
    }
  }

  private func getGrowthRating(outlook: String) -> Int {
    if outlook.contains("rapid") || outlook.contains("fast") {
      return 5
    } else if outlook.contains("strong") || outlook.contains("above average") {
      return 4
    } else if outlook.contains("steady") || outlook.contains("stable") {
      return 3
    } else if outlook.contains("slow") || outlook.contains("modest") {
      return 2
    } else if outlook.contains("decline") || outlook.contains("limited") {
      return 1
    } else {
      return 3  // Default to moderate
    }
  }

  private func getEducationLevel(education: String) -> String {
    if education.contains("PhD") || education.contains("Doctorate") {
      return "Doctorate"
    } else if education.contains("Master") {
      return "Master's"
    } else if education.contains("Bachelor") {
      return "Bachelor's"
    } else if education.contains("Associate") {
      return "Associate's"
    } else if education.contains("Certificate") || education.contains("Certification") {
      return "Certificate"
    } else if education.contains("High School") {
      return "High School"
    } else {
      return "Various"
    }
  }

  private func getProgressColor(value: Double) -> Color {
    if value < 0.3 {
      return .red
    } else if value < 0.7 {
      return .orange
    } else {
      return .green
    }
  }

  // Sample data for skill resources
  private func getSkillResources() -> [(
    name: String, description: String, icon: String, color: Color
  )] {
    return [
      (
        name: "Online Courses",
        description: "Structured learning paths with certificates",
        icon: "laptopcomputer",
        color: .blue
      ),
      (
        name: "Hands-on Projects",
        description: "Build practical skills through real projects",
        icon: "hammer",
        color: .orange
      ),
      (
        name: "Industry Mentorship",
        description: "Connect with professionals in the field",
        icon: "person.2.fill",
        color: .green
      ),
    ]
  }

  // Sample data for personality traits
  private func getPersonalityTraits() -> [(trait: String, score: String, label: String)] {
    return [
      (
        trait: "Analytical",
        score: "85%",
        label: "Match"
      ),
      (
        trait: "Detail-Oriented",
        score: "78%",
        label: "Match"
      ),
      (
        trait: "Problem-Solver",
        score: "92%",
        label: "Match"
      ),
    ]
  }

  // Sample education path data
  private func getEducationPath() -> [(
    level: String, description: String, timeline: String, icon: String, isRequired: Bool
  )] {
    return [
      (
        level: "High School",
        description: "Focus on math, science, and computer courses",
        timeline: "4 years",
        icon: "book.fill",
        isRequired: true
      ),
      (
        level: "Bachelor's Degree",
        description: "Major in computer science, information technology, or related field",
        timeline: "4 years",
        icon: "graduationcap.fill",
        isRequired: true
      ),
      (
        level: "Master's Degree",
        description: "Advanced specialization in a specific area",
        timeline: "1-2 years",
        icon: "graduationcap.fill",
        isRequired: false
      ),
    ]
  }

  // Sample recommended programs data
  private func getRecommendedPrograms() -> [(
    name: String, institution: String, duration: String, format: String, initials: String
  )] {
    return [
      (
        name: "Computer Science",
        institution: "State University",
        duration: "4 years",
        format: "On Campus/Online",
        initials: "SU"
      ),
      (
        name: "Information Technology",
        institution: "Tech Institute",
        duration: "3-4 years",
        format: "On Campus",
        initials: "TI"
      ),
      (
        name: "Software Engineering",
        institution: "National University",
        duration: "4 years",
        format: "Online",
        initials: "NU"
      ),
    ]
  }

  // Sample career path data
  private func getCareerPath() -> [(
    title: String, description: String, salary: String, yearsExperience: String, isCurrent: Bool
  )] {
    return [
      (
        title: "Entry Level",
        description:
          "Starting position focusing on basic responsibilities and learning the fundamentals",
        salary: "45,000-60,000",
        yearsExperience: "0-2",
        isCurrent: false
      ),
      (
        title: career.title,
        description: "Mid-level position with increased responsibilities and specialized skills",
        salary: "\(career.salaryRange.lowerBound)-\(career.salaryRange.upperBound)",
        yearsExperience: "3-5",
        isCurrent: true
      ),
      (
        title: "Senior Position",
        description: "Leadership role with strategic planning and team management",
        salary: "\(career.salaryRange.upperBound + 20000)-\(career.salaryRange.upperBound + 50000)",
        yearsExperience: "5-10",
        isCurrent: false
      ),
    ]
  }

  // Sample milestone data
  private func getMilestones() -> [(title: String, description: String, icon: String, color: Color)]
  {
    return [
      (
        title: "Education Requirements",
        description: "Complete necessary degrees and certifications",
        icon: "book.fill",
        color: .blue
      ),
      (
        title: "Entry Level Experience",
        description: "Gain 1-2 years of foundational experience",
        icon: "briefcase.fill",
        color: .orange
      ),
      (
        title: "Specialized Skills",
        description: "Develop expertise in key technical areas",
        icon: "hammer.fill",
        color: .purple
      ),
      (
        title: "Professional Network",
        description: "Build connections with industry professionals",
        icon: "person.3.fill",
        color: .green
      ),
    ]
  }
  
  // MARK: - Data Loading Functions
  
  @MainActor
  private func loadCareerData() async {
    isLoading = true
    
    do {
      // Load related careers
      relatedCareers = try await careerService.getRelatedCareers(to: career, limit: 3)
      
      // Check if career is bookmarked
      let bookmarks = try await careerService.fetchCareerBookmarks()
      isBookmarked = bookmarks.contains { $0.careerTitle == career.title }
      
    } catch {
      self.error = error
      // Fallback to sample data
      relatedCareers = Career.sampleCareers.filter { 
        $0.field == career.field && $0.title != career.title 
      }.prefix(3).map { $0 }
    }
    
    isLoading = false
  }
  
  @MainActor
  private func toggleBookmark() async {
    do {
      if isBookmarked {
        try await careerService.removeCareerBookmark(careerTitle: career.title)
        isBookmarked = false
      } else {
        try await careerService.saveCareerBookmark(career: career)
        isBookmarked = true
        
        // Track bookmark action
        try? await careerService.trackCareerExploration(career: career, action: .bookmarked)
      }
    } catch {
      // Handle error silently for now
      print("Failed to toggle bookmark: \(error)")
    }
  }
}

// Related career card component
struct RelatedCareerCard: View {
  let career: Career

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: getCareerIcon(field: career.field))
          .font(.title3)
          .foregroundColor(.tmiPrimary.opacity(0.7))

        Spacer()

        Text(career.field)
          .font(.caption)
          .foregroundColor(.tmiSecondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(Color.tmiSecondary.opacity(0.1))
          )
      }

      Text(career.title)
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(.tmiText)

      Divider()

      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("$\(career.salaryRange.lowerBound/1000)k-$\(career.salaryRange.upperBound/1000)k")
            .font(.subheadline)
            .foregroundColor(.tmiSecondary)

          Text("Annual Salary")
            .font(.caption)
            .foregroundColor(.gray)
        }

        Spacer()

        Image(systemName: "arrow.right")
          .foregroundColor(.tmiPrimary)
          .padding(8)
          .background(
            Circle()
              .fill(Color.tmiPrimary.opacity(0.1))
          )
      }
    }
    .padding(16)
    .frame(width: 240, height: 160)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    )
  }

  private func getCareerIcon(field: String) -> String {
    switch field {
    case "Technology": return "desktopcomputer"
    case "Healthcare": return "heart.text.square"
    case "Education": return "book"
    case "Business": return "briefcase"
    case "Engineering": return "gearshape.2"
    case "Arts": return "paintpalette"
    case "Science": return "atom"
    default: return "star"
    }
  }
}

// School finder view
struct SchoolFinderView: View {
  let careerField: String
  @Environment(\.presentationMode) var presentationMode
  @State private var searchText = ""
  @State private var selectedProgram: String? = nil
  @State private var selectedLocation: String? = nil
  @State private var selectedFormat: String? = nil
  @State private var animateContent = false

  // Sample data
  let programs = ["Bachelor's Degree", "Master's Degree", "Certificate", "Associate's Degree"]
  let locations = ["Any Location", "Northeast", "Southeast", "Midwest", "Southwest", "West Coast"]
  let formats = ["Any Format", "On Campus", "Online", "Hybrid"]

  var body: some View {
    NavigationView {
      ZStack {
        // Background with gradient
        LinearGradient(
          gradient: Gradient(colors: [
            Color.tmiBackground,
            Color.tmiPrimary.opacity(0.1),
            Color.tmiBackground,
          ]),
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // Hero section
            ZStack(alignment: .bottomLeading) {
              Rectangle()
                .fill(
                  LinearGradient(
                    gradient: Gradient(colors: [
                      Color.tmiPrimary,
                      Color.tmiPrimary.opacity(0.8),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .frame(height: 160)

              HStack {
                VStack(alignment: .leading, spacing: 8) {
                  Text("Find Your Perfect School")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)

                  Text("\(careerField) Programs")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .opacity(animateContent ? 1 : 0)
                    .offset(y: animateContent ? 0 : 20)
                    .animation(
                      .spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent
                    )
                }

                Spacer()

                Image(systemName: "building.columns.fill")
                  .font(.system(size: 60))
                  .foregroundColor(.white.opacity(0.2))
              }
              .padding(.horizontal, 20)
              .padding(.bottom, 20)
            }

            // Search and filters
            VStack(alignment: .leading, spacing: 16) {
              Text("Search Programs")
                .font(.headline)
                .foregroundColor(.tmiPrimary)

              HStack {
                Image(systemName: "magnifyingglass")
                  .foregroundColor(.gray)

                TextField("Search schools or programs...", text: $searchText)
              }
              .padding()
              .background(
                RoundedRectangle(cornerRadius: 10)
                  .fill(Color.white)
                  .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
              )

              // Filter options
              VStack(alignment: .leading, spacing: 16) {
                Text("Filter Options")
                  .font(.headline)
                  .foregroundColor(.tmiPrimary)

                // Program type filter
                VStack(alignment: .leading, spacing: 8) {
                  Text("Program Type")
                    .font(.subheadline)
                    .foregroundColor(.tmiText)

                  ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                      ForEach(programs, id: \.self) { program in
                        CareerDetailFilterButton(
                          title: program,
                          isSelected: selectedProgram == program,
                          action: {
                            selectedProgram = selectedProgram == program ? nil : program
                          }
                        )
                      }
                    }
                  }
                }

                // Location filter
                VStack(alignment: .leading, spacing: 8) {
                  Text("Location")
                    .font(.subheadline)
                    .foregroundColor(.tmiText)

                  ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                      ForEach(locations, id: \.self) { location in
                        CareerDetailFilterButton(
                          title: location,
                          isSelected: selectedLocation == location,
                          action: {
                            selectedLocation = selectedLocation == location ? nil : location
                          }
                        )
                      }
                    }
                  }
                }

                // Format filter
                VStack(alignment: .leading, spacing: 8) {
                  Text("Format")
                    .font(.subheadline)
                    .foregroundColor(.tmiText)

                  ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                      ForEach(formats, id: \.self) { format in
                        CareerDetailFilterButton(
                          title: format,
                          isSelected: selectedFormat == format,
                          action: {
                            selectedFormat = selectedFormat == format ? nil : format
                          }
                        )
                      }
                    }
                  }
                }
              }

              // Search button
              Button(action: {
                // Perform search
              }) {
                Text("Search Programs")
                  .font(.headline)
                  .foregroundColor(.white)
                  .frame(maxWidth: .infinity)
                  .padding()
                  .background(
                    RoundedRectangle(cornerRadius: 12)
                      .fill(Color.tmiPrimary)
                  )
              }
              .padding(.top, 16)
            }
            .padding(20)
            .background(
              RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 20)
            .offset(y: animateContent ? 0 : 30)
            .opacity(animateContent ? 1 : 0)
            .animation(
              .spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
          }
          .padding(.bottom, 20)
        }
      }
      .navigationTitle("Find Schools")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: {
            presentationMode.wrappedValue.dismiss()
          }) {
            Image(systemName: "xmark")
              .foregroundColor(.tmiPrimary)
          }
        }
      }
      .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          animateContent = true
        }
      }
    }
  }
}

// Filter button component
struct CareerDetailFilterButton: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(isSelected ? Color.tmiPrimary : Color.tmiSecondary.opacity(0.1))
        )
        .foregroundColor(isSelected ? .white : .tmiText)
    }
  }
}

// Preview
#Preview {
  NavigationView {
    CareerDetailView(career: Career.sampleCareers.first!)
  }
}
