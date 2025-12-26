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
  @State private var careerResources: [Resource] = []
  @State private var isBookmarked = false
  @State private var isLoading = false
  @State private var error: Error?
  @State private var showResourcesSheet = false
  @State private var alignmentScore: Double = 0.0
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
      // Use unified TMI background
      TMIBackgroundView(variant: .career)
        .ignoresSafeArea()

      ScrollView {
        VStack(spacing: 0) {
          // Hero header
          heroHeader

          // Tab selection
          tabSelector

          // Main content container with TMI glass morphism effect
          ZStack {
            RoundedRectangle(cornerRadius: 30)
              .fill(Color.white.opacity(0.05))
              .background(
                RoundedRectangle(cornerRadius: 30)
                  .fill(.ultraThinMaterial)
                  .opacity(0.3)
              )
              .overlay(
                RoundedRectangle(cornerRadius: 30)
                  .stroke(
                    LinearGradient(
                      colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                  )
              )
              .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: -5)

            // Content based on selected tab
            VStack {
              TabView(selection: $selectedTab) {
                overviewTab.tag(0)
                skillsTab.tag(1)
                educationTab.tag(2)
                pathwayTab.tag(3)
              }
              .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

              // Related resources section
              if !careerResources.isEmpty {
                relatedResourcesSection
                  .opacity(animateContent ? 1 : 0)
                  .offset(y: animateContent ? 0 : 20)
                  .animation(
                    .spring(response: 0.5, dampingFraction: 0.8).delay(0.25), value: animateContent)
              }
              
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
            .foregroundColor(.white)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: {
            Task {
              await toggleBookmark()
            }
          }) {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
              .foregroundColor(.white)
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
    .sheet(isPresented: $showResourcesSheet) {
      CareerResourcesView(career: career, resources: careerResources)
    }
  }

  // MARK: - Hero Header
  private var heroHeader: some View {
    ZStack {
      // Enhanced background with gradient and glass morphism
      RoundedRectangle(cornerRadius: 0)
        .fill(
          LinearGradient(
            gradient: Gradient(stops: [
              .init(color: Color.tmiPrimary.opacity(0.4), location: 0.0),
              .init(color: Color.tmiSecondary.opacity(0.3), location: 0.7),
              .init(color: Color.clear, location: 1.0)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .background(
          RoundedRectangle(cornerRadius: 0)
            .fill(.ultraThinMaterial)
            .opacity(0.8)
        )

      // Floating geometric elements for visual interest
      GeometryReader { geometry in
        ForEach(0..<8) { i in
          let size = CGFloat.random(in: 8...24)
          let xPos = CGFloat.random(in: 0...geometry.size.width)
          let yPos = CGFloat.random(in: 0...geometry.size.height)
          
          RoundedRectangle(cornerRadius: size / 4)
            .fill(Color.white.opacity(0.1))
            .frame(width: size, height: size)
            .position(x: xPos, y: yPos)
            .rotationEffect(.degrees(Double.random(in: 0...360)))
            .opacity(animateContent ? 1 : 0)
            .animation(
              Animation.easeInOut(duration: Double.random(in: 3...6))
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...2)),
              value: animateContent
            )
        }
      }

      // Enhanced career info with modern layout
      VStack(spacing: 20) {
        // Header section with improved typography
        HStack(alignment: .top, spacing: 16) {
          // Enhanced career icon with multiple layers
          ZStack {
            // Outer glow effect
            Circle()
              .fill(
                RadialGradient(
                  gradient: Gradient(colors: [
                    Color.tmiSecondary.opacity(0.3),
                    Color.clear
                  ]),
                  center: .center,
                  startRadius: 30,
                  endRadius: 50
                )
              )
              .frame(width: 100, height: 100)
            
            // Main icon background
            Circle()
              .fill(
                LinearGradient(
                  gradient: Gradient(colors: [
                    Color.white.opacity(0.2),
                    Color.white.opacity(0.1)
                  ]),
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 70, height: 70)
              .overlay(
                Circle()
                  .stroke(
                    LinearGradient(
                      gradient: Gradient(colors: [
                        Color.white.opacity(0.3),
                        Color.clear
                      ]),
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                  )
              )

            Image(systemName: getCareerIcon(field: career.field))
              .font(.system(size: 32, weight: .medium))
              .foregroundColor(.white)
          }
          .opacity(animateContent ? 1 : 0)
          .scaleEffect(animateContent ? 1 : 0.6)
          .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1), value: animateContent)

          VStack(alignment: .leading, spacing: 8) {
            // Career title with enhanced typography
            Text(career.title)
              .font(.system(size: 32, weight: .bold, design: .rounded))
              .foregroundColor(.white)
              .opacity(animateContent ? 1 : 0)
              .offset(y: animateContent ? 0 : 30)
              .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.2), value: animateContent)

            // Field badge with improved design
            HStack(spacing: 6) {
              Circle()
                .fill(Color.tmiSecondary)
                .frame(width: 8, height: 8)
              
              Text(career.field)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(Color.white.opacity(0.15))
                .background(
                  Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
                )
            )
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 30)
            .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.3), value: animateContent)
            
            Spacer()
          }
        }

        // Enhanced stats cards with improved design
        HStack(spacing: 12) {
          // Salary Card
          CareerStatCard(
            icon: "dollarsign.circle.fill",
            title: "$\(career.salaryRange.lowerBound/1000)k-$\(career.salaryRange.upperBound/1000)k",
            subtitle: "Annual Salary",
            color: Color.green,
            animateContent: animateContent,
            delay: 0.4
          )
          
          // Growth Card
          CareerStatCard(
            icon: "chart.line.uptrend.xyaxis",
            title: getGrowthCategory(outlook: career.jobOutlook),
            subtitle: "Job Growth",
            color: Color.blue,
            animateContent: animateContent,
            delay: 0.5
          )
          
          // Education Card
          CareerStatCard(
            icon: "graduationcap.fill",
            title: getEducationLevel(education: career.education),
            subtitle: "Education",
            color: Color.purple,
            animateContent: animateContent,
            delay: 0.6
          )
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 24)
    }
    .frame(height: 280)
  }

  // MARK: - Enhanced Tab Selector
  private var tabSelector: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) {
        ForEach(Array(zip(["Overview", "Skills", "Education", "Pathway"],
                         ["info.circle", "star.fill", "graduationcap.fill", "arrow.up.right"])),
                id: \.0) { tab, icon in
          let index = ["Overview", "Skills", "Education", "Pathway"].firstIndex(of: tab) ?? 0
          
          Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
              selectedTab = index
            }
          }) {
            HStack(spacing: 8) {
              Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.6))
              
              Text(tab)
                .font(.system(size: 16, weight: selectedTab == index ? .semibold : .medium))
                .foregroundColor(selectedTab == index ? .white : .white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
              Group {
                if selectedTab == index {
                  RoundedRectangle(cornerRadius: 20)
                    .fill(
                      LinearGradient(
                        gradient: Gradient(colors: [
                          Color.tmiPrimary.opacity(0.8),
                          Color.tmiSecondary.opacity(0.6)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                    )
                    .overlay(
                      RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                } else {
                  RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                      RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                }
              }
            )
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 20)
    }
    .padding(.vertical, 16)
    .background(
      Rectangle()
        .fill(Color.black.opacity(0.2))
        .background(.ultraThinMaterial.opacity(0.8))
    )
  }

  // MARK: - Overview Tab
  private var overviewTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      // About section with enhanced card design
      VStack(alignment: .leading, spacing: 16) {
        sectionHeader(title: "About This Career", icon: "info.circle")
        
        Text(career.description)
          .font(.system(size: 16, weight: .regular))
          .foregroundColor(.white)
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(6)
          .opacity(animateContent ? 1 : 0)
          .offset(y: animateContent ? 0 : 10)
          .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateContent)
      }
      .padding(24)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.white.opacity(0.06))
          .background(
            RoundedRectangle(cornerRadius: 20)
              .fill(.ultraThinMaterial)
              .opacity(0.8)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
              )
          )
          .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
      )

      // Job outlook section with enhanced design
      VStack(alignment: .leading, spacing: 16) {
        sectionHeader(title: "Job Outlook", icon: "chart.line.uptrend.xyaxis")
        
        Text(career.jobOutlook)
          .font(.system(size: 16, weight: .regular))
          .foregroundColor(.white)
          .fixedSize(horizontal: false, vertical: true)
          .lineSpacing(6)
          .opacity(animateContent ? 1 : 0)
          .offset(y: animateContent ? 0 : 10)
          .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2), value: animateContent)
        
        // Enhanced growth indicator with modern design
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Growth Potential")
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.white.opacity(0.8))
            
            HStack(spacing: 4) {
              ForEach(0..<5) { i in
                Image(systemName: "star.fill")
                  .font(.system(size: 16))
                  .foregroundColor(
                    i < getGrowthRating(outlook: career.jobOutlook) ? .yellow : .white.opacity(0.2)
                  )
                  .scaleEffect(animateContent ? 1 : 0.5)
                  .animation(
                    .spring(response: 0.5, dampingFraction: 0.7).delay(0.3 + Double(i) * 0.05),
                    value: animateContent
                  )
              }
            }
          }
          
          Spacer()
          
          // Growth category badge
          Text(getGrowthCategory(outlook: career.jobOutlook))
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
              Capsule()
                .fill(
                  LinearGradient(
                    colors: [Color.green.opacity(0.8), Color.blue.opacity(0.6)],
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
            )
        }
        .padding(.top, 12)
      }
      .padding(24)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.white.opacity(0.06))
          .background(
            RoundedRectangle(cornerRadius: 20)
              .fill(.ultraThinMaterial)
              .opacity(0.8)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
              )
          )
          .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
      )

      // Enhanced progress section with modern design
      VStack(alignment: .leading, spacing: 16) {
        sectionHeader(title: "Your Progress", icon: "chart.bar.fill")
        
        VStack(spacing: 16) {
          ForEach(Array(progressData.enumerated()), id: \.offset) { index, item in
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text(item.0)
                  .font(.system(size: 16, weight: .medium))
                  .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(item.1 * 100))%")
                  .font(.system(size: 14, weight: .bold))
                  .foregroundColor(getProgressColor(value: item.1))
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(
                    Capsule()
                      .fill(getProgressColor(value: item.1).opacity(0.15))
                  )
              }
              
              // Enhanced progress bar with animation
              GeometryReader { geometry in
                ZStack(alignment: .leading) {
                  RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 10)
                  
                  RoundedRectangle(cornerRadius: 6)
                    .fill(
                      LinearGradient(
                        colors: [
                          getProgressColor(value: item.1),
                          getProgressColor(value: item.1).opacity(0.7)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                      )
                    )
                    .frame(
                      width: animateContent ? CGFloat(item.1) * geometry.size.width : 0,
                      height: 10
                    )
                    .animation(
                      .spring(response: 0.8, dampingFraction: 0.8).delay(0.4 + Double(index) * 0.1),
                      value: animateContent
                    )
                }
              }
              .frame(height: 10)
            }
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(
              .spring(response: 0.6, dampingFraction: 0.8).delay(0.3 + Double(index) * 0.1),
              value: animateContent
            )
          }
        }

        // Enhanced action button
        Button(action: {
          // Action to create personalized plan
        }) {
          HStack(spacing: 8) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 18, weight: .semibold))
            
            Text("Create Personalized Plan")
              .font(.system(size: 16, weight: .semibold))
          }
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(
                LinearGradient(
                  colors: [Color.tmiPrimary, Color.tmiSecondary],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .shadow(color: Color.tmiPrimary.opacity(0.3), radius: 8, x: 0, y: 4)
          )
        }
        .buttonStyle(.plain)
        .scaleEffect(animateContent ? 1 : 0.9)
        .opacity(animateContent ? 1 : 0)
        .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(0.8), value: animateContent)
        .padding(.top, 20)
      }
      .padding(24)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.white.opacity(0.06))
          .background(
            RoundedRectangle(cornerRadius: 20)
              .fill(.ultraThinMaterial)
              .opacity(0.8)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
              )
          )
          .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
      )
      
      // Recommended TMI Modules section
      VStack(alignment: .leading, spacing: 16) {
        sectionHeader(title: "Recommended TMI Modules", icon: "lightbulb.fill")
        
        Text("These intervention models can help students build skills for this career:")
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(.white.opacity(0.8))
          .fixedSize(horizontal: false, vertical: true)
        
        VStack(spacing: 12) {
          ForEach(Array(getRecommendedTMIModels(for: career).enumerated()), id: \.offset) { index, model in
            TMIModuleCard(model: model)
              .opacity(animateContent ? 1 : 0)
              .offset(y: animateContent ? 0 : 20)
              .animation(
                .spring(response: 0.6, dampingFraction: 0.8).delay(0.9 + Double(index) * 0.1),
                value: animateContent
              )
          }
        }
      }
      .padding(24)
      .background(
        RoundedRectangle(cornerRadius: 20)
          .fill(Color.white.opacity(0.06))
          .background(
            RoundedRectangle(cornerRadius: 20)
              .fill(.ultraThinMaterial)
              .opacity(0.8)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.25), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1.5
              )
          )
          .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
      )
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Skills Tab
  private var skillsTab: some View {
    VStack(alignment: .leading, spacing: 20) {
      // Enhanced core skills section
      VStack(alignment: .leading, spacing: 16) {
        sectionHeader(title: "Required Skills", icon: "star.fill")
        
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
          ForEach(Array(career.skills.enumerated()), id: \.offset) { index, skill in
            HStack(spacing: 10) {
              ZStack {
                Circle()
                  .fill(Color.green.opacity(0.2))
                  .frame(width: 24, height: 24)
                
                Image(systemName: "checkmark")
                  .foregroundColor(.green)
                  .font(.system(size: 12, weight: .bold))
              }
              
              Text(skill)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
              RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .background(
                  RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .opacity(0.6)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(
                      LinearGradient(
                        colors: [.white.opacity(0.2), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 1
                    )
                )
            )
            .opacity(animateContent ? 1 : 0)
            .offset(y: animateContent ? 0 : 20)
            .animation(
              .spring(response: 0.6, dampingFraction: 0.8).delay(0.1 + Double(index) * 0.05),
              value: animateContent
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
                .foregroundColor(.white)

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
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                    .foregroundColor(.white)

                  Text(trait.label)
                    .font(.caption2)
                    .foregroundColor(.tmiSecondary)
                }
              }

              Text(trait.trait)
                .font(.caption)
                .foregroundColor(.white)
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
          .foregroundColor(.white)
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
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
          .foregroundColor(.white)
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
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                  .foregroundColor(.white)
              }

              VStack(alignment: .leading, spacing: 4) {
                Text(program.name)
                  .font(.headline)
                  .foregroundColor(.white)

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
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
                .foregroundColor(.white)

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
          .fill(Color.white.opacity(0.05))
          .background(
            RoundedRectangle(cornerRadius: 16)
              .fill(.ultraThinMaterial)
              .opacity(0.3)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(
                LinearGradient(
                  colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
          .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
          .foregroundColor(.white)

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
  
  // MARK: - Related Resources Section
  private var relatedResourcesSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Text("Helpful Resources")
          .font(.headline)
          .foregroundColor(.white)

        Spacer()

        Button(action: {
          showResourcesSheet = true
        }) {
          Text("View All")
            .font(.subheadline)
            .foregroundColor(.tmiSecondary)
        }
      }
      .padding(.horizontal, 20)

      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(careerResources.prefix(3), id: \.id) { resource in
            CareerResourceCard(resource: resource)
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
      }
    }
    .padding(.top, 24)
  }

  // MARK: - Helper Components
  private func sectionHeader(title: String, icon: String) -> some View {
    HStack(spacing: 12) {
      ZStack {
        Circle()
          .fill(Color.tmiPrimary.opacity(0.2))
          .frame(width: 32, height: 32)
        
        Image(systemName: icon)
          .foregroundColor(.white)
          .font(.system(size: 16, weight: .semibold))
      }
      
      Text(title)
        .font(.system(size: 20, weight: .bold, design: .rounded))
        .foregroundColor(.white)
      
      Spacer()
    }
    .opacity(animateContent ? 1 : 0)
    .offset(y: animateContent ? 0 : -10)
    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animateContent)
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
  
  // MARK: - TMI Model Recommendations
  
  private func getRecommendedTMIModels(for career: Career) -> [(model: TMIPlanModel, reason: String)] {
    var recommendations: [(model: TMIPlanModel, reason: String)] = []
    
    // Always recommend Chase Your Space for careers with clear pathways
    recommendations.append((
      model: .chaseYourSpace,
      reason: "Cultivate career pathway for students who know they want to pursue \(career.field)"
    ))
    
    // Recommend Acknowledge Interests for creative and specialized fields
    if career.field.lowercased().contains("arts") ||
       career.field.lowercased().contains("creative") ||
       career.field.lowercased().contains("technology") {
      recommendations.append((
        model: .acknowledgeInterests,
        reason: "Connect student interests in \(career.field) to classroom learning"
      ))
    }
    
    // Recommend Align Your Mind for technical/analytical careers
    if career.field.lowercased().contains("technology") ||
       career.field.lowercased().contains("science") ||
       career.field.lowercased().contains("engineering") ||
       career.field.lowercased().contains("finance") {
      recommendations.append((
        model: .alignYourMind,
        reason: "Build focus and organization skills needed for \(career.field)"
      ))
    }
    
    // Recommend leadership models for business/management careers
    if career.field.lowercased().contains("business") ||
       career.field.lowercased().contains("management") ||
       career.title.lowercased().contains("leader") {
      recommendations.append((
        model: .bullyToBoss,
        reason: "Channel leadership energy into positive roles like \(career.title)"
      ))
    }
    
    // Recommend confidence-building for helping professions
    if career.field.lowercased().contains("health") ||
       career.field.lowercased().contains("education") ||
       career.field.lowercased().contains("social") {
      recommendations.append((
        model: .meekToProtector,
        reason: "Build confidence for careers in \(career.field) that require assertiveness"
      ))
    }
    
    // Limit to top 3 recommendations
    return Array(recommendations.prefix(3))
  }
  
  // MARK: - Data Loading Functions
  
  @MainActor
  private func loadCareerData() async {
    isLoading = true
    
    do {
      // Load related careers
      relatedCareers = try await careerService.getRelatedCareers(to: career, limit: 3)
      
      // Load career-specific resources
      careerResources = await careerService.getCareerResources(for: career)
      
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

// MARK: - CareerStatCard Component

struct CareerStatCard: View {
  let icon: String
  let title: String
  let subtitle: String
  let color: Color
  let animateContent: Bool
  let delay: Double
  
  var body: some View {
    VStack(spacing: 8) {
      // Icon with enhanced styling
      ZStack {
        Circle()
          .fill(
            RadialGradient(
              gradient: Gradient(colors: [
                color.opacity(0.2),
                color.opacity(0.1)
              ]),
              center: .center,
              startRadius: 15,
              endRadius: 25
            )
          )
          .frame(width: 44, height: 44)
        
        Image(systemName: icon)
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(color)
      }
      
      // Title and subtitle with improved typography
      VStack(spacing: 2) {
        Text(title)
          .font(.system(size: 16, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        
        Text(subtitle)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.white.opacity(0.7))
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .padding(.horizontal, 12)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.08))
        .background(
          RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .opacity(0.6)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(
              LinearGradient(
                gradient: Gradient(colors: [
                  Color.white.opacity(0.2),
                  Color.clear
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
    )
    .opacity(animateContent ? 1 : 0)
    .offset(y: animateContent ? 0 : 20)
    .scaleEffect(animateContent ? 1 : 0.9)
    .animation(
      .spring(response: 0.8, dampingFraction: 0.8).delay(delay),
      value: animateContent
    )
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
        .foregroundColor(.white)

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
          .foregroundColor(.white)
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
        // Use unified TMI background
        TMIBackgroundView(variant: .career)
          .ignoresSafeArea()

        ScrollView {
          VStack(alignment: .leading, spacing: 24) {
            // Hero section
            ZStack(alignment: .bottomLeading) {
              RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .background(
                  RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 16)
                    .stroke(
                      LinearGradient(
                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 1
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
                .foregroundColor(.white)

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
                  .foregroundColor(.white)

                // Program type filter
                VStack(alignment: .leading, spacing: 8) {
                  Text("Program Type")
                    .font(.subheadline)
                    .foregroundColor(.white)

                  programTypeFilterList
                }

                // Location filter
                VStack(alignment: .leading, spacing: 8) {
                  Text("Location")
                    .font(.subheadline)
                    .foregroundColor(.white)

                  locationFilterList
                }

                // Format filter
                VStack(alignment: .leading, spacing: 8) {
                  Text("Format")
                    .font(.subheadline)
                    .foregroundColor(.white)

                  formatFilterList
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
                .fill(Color.white.opacity(0.05))
                .background(
                  RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
                )
                .overlay(
                  RoundedRectangle(cornerRadius: 16)
                    .stroke(
                      LinearGradient(
                        colors: [.white.opacity(0.2), .clear, .white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      ),
                      lineWidth: 1
                    )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
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
              .foregroundColor(.white)
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
  
  private var programTypeFilterList: some View {
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
  
  private var locationFilterList: some View {
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
  
  private var formatFilterList: some View {
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

// MARK: - Career Resource Card

struct CareerResourceCard: View {
  let resource: Resource
  @State private var isHovered = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        ZStack {
          Circle()
            .fill(resource.category.color.opacity(0.2))
            .frame(width: 40, height: 40)

          Image(systemName: resource.category.icon)
            .font(.system(size: 20))
            .foregroundColor(resource.category.color)
        }

        Spacer()

        Text(resource.category.rawValue.capitalized)
          .font(.system(size: 10, weight: .medium))
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(
            Capsule()
              .fill(resource.category.color.opacity(0.1))
          )
          .foregroundColor(resource.category.color)
      }

      Text(resource.title)
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .lineLimit(2)
        .multilineTextAlignment(.leading)

      Text(resource.description)
        .font(.system(size: 12))
        .foregroundColor(.white.opacity(0.7))
        .lineLimit(2)

      HStack {
        ForEach(resource.tags.prefix(2), id: \.self) { tag in
          Text(tag)
            .font(.system(size: 9))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              Capsule()
                .fill(Color.white.opacity(0.1))
            )
            .foregroundColor(.white.opacity(0.8))
        }
        Spacer()
      }
    }
    .padding(12)
    .frame(width: 180, height: 140)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .opacity(0.8)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(
              LinearGradient(
                colors: [resource.category.color.opacity(0.3), Color.clear, resource.category.color.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
    )
    .scaleEffect(isHovered ? 1.02 : 1.0)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
  }
}

// MARK: - TMI Module Card

struct TMIModuleCard: View {
  let model: (model: TMIPlanModel, reason: String)
  
  private var modelColor: Color {
    switch model.model {
    case .chaseYourSpace: return .blue
    case .acknowledgeInterests: return .pink
    case .alignYourMind: return .purple
    case .directAndCorrect: return .orange
    case .bullyToBoss: return .red
    case .meekToProtector: return .green
    }
  }
  
  private var modelIcon: String {
    switch model.model {
    case .chaseYourSpace: return "airplane.departure"
    case .acknowledgeInterests: return "heart.fill"
    case .alignYourMind: return "brain.head.profile"
    case .directAndCorrect: return "arrow.up.forward.circle.fill"
    case .bullyToBoss: return "person.fill.badge.plus"
    case .meekToProtector: return "shield.lefthalf.filled"
    }
  }
  
  var body: some View {
    HStack(spacing: 16) {
      // Icon
      ZStack {
        Circle()
          .fill(modelColor.opacity(0.2))
          .frame(width: 48, height: 48)
        
        Image(systemName: modelIcon)
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(modelColor)
      }
      
      VStack(alignment: .leading, spacing: 6) {
        Text(model.model.rawValue)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.white)
        
        Text(model.reason)
          .font(.system(size: 14, weight: .regular))
          .foregroundColor(.white.opacity(0.8))
          .fixedSize(horizontal: false, vertical: true)
      }
      
      Spacer()
    }
    .padding(16)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.white.opacity(0.05))
        .background(
          RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .opacity(0.5)
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          LinearGradient(
            colors: [modelColor.opacity(0.3), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
  }
}

// MARK: - Career Resources Sheet View

struct CareerResourcesView: View {
  let career: Career
  let resources: [Resource]
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
        TMIBackgroundView(variant: .default)
          .ignoresSafeArea()

        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
            ForEach(resources, id: \.id) { resource in
              NavigationLink(destination: ResourceDetailView(resource: resource)) {
                ResourceCard(resource: resource)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(20)
        }
      }
      .navigationTitle("\(career.title) Resources")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .preferredColorScheme(.dark)
  }
}


// Preview
#Preview {
  NavigationView {
    CareerDetailView(career: Career.sampleCareers.first!)
  }
}
