//
//  ImprovedAddStudentView.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI
import Observation

struct AddStudentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var stateModel = AddStudentStateModel()
    
    let onStudentAdded: (Student) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50))
                                .foregroundColor(.tmiSecondary)
                                .padding(.top, 20)
                            
                            Text("Add New Student")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Enter the student's basic information")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.bottom, 10)
                        
                        // Form
                        TMIGlassCard(style: .default) {
                            VStack(spacing: 20) {
                                // Name field
                                TMITextField(
                                    icon: "person.fill",
                                    placeholder: "Student Name",
                                    text: $stateModel.name
                                )
                                
                                // Grade field
                                TMITextField(
                                    icon: "number.square",
                                    placeholder: "Grade Level",
                                    text: $stateModel.grade
                                )
                                
                                // Student ID field
                                TMITextField(
                                    icon: "barcode",
                                    placeholder: "Student ID (optional)",
                                    text: $stateModel.studentID
                                )
                                
                                // Date of Birth
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Date of Birth", systemImage: "calendar")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    DatePicker(
                                        "Date of Birth",
                                        selection: $stateModel.dateOfBirth,
                                        in: Calendar.current.date(byAdding: .year, value: -25, to: Date())!...Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.compact)
                                    .accentColor(.tmiSecondary)
                                    .labelsHidden()
                                }
                                .padding(.vertical, 8)
                                
                                // Interests Section
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Interests (\(stateModel.selectedInterestCount))", systemImage: "heart")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Button(action: {
                                        stateModel.showInterestPicker()
                                    }) {
                                        HStack {
                                            Text(stateModel.interests.isEmpty ? "Add interests" : stateModel.interests.map { $0.name }.joined(separator: ", "))
                                                .foregroundColor(stateModel.interests.isEmpty ? .white.opacity(0.6) : .white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.white.opacity(0.6))
                                                .font(.system(size: 14))
                                        }
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.05))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(.ultraThinMaterial)
                                                        .opacity(0.3)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // Hobbies Section
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Hobbies (\(stateModel.selectedHobbyCount))", systemImage: "gamecontroller")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Button(action: {
                                        stateModel.showHobbyPicker()
                                    }) {
                                        HStack {
                                            Text(stateModel.hobbies.isEmpty ? "Add hobbies" : stateModel.hobbies.map { $0.name }.joined(separator: ", "))
                                                .foregroundColor(stateModel.hobbies.isEmpty ? .white.opacity(0.6) : .white)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.white.opacity(0.6))
                                                .font(.system(size: 14))
                                        }
                                        .padding(16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.05))
                                                .background(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(.ultraThinMaterial)
                                                        .opacity(0.3)
                                                )
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.3), .clear, .white.opacity(0.1)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Error message
                        if let errorMessage = stateModel.errorMessage {
                            TMIGlassCard(style: .error) {
                                HStack(spacing: 12) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                    
                                    Text(errorMessage)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                            }
                        }
                        
                        // Submit button
                        TMIButton(
                            text: "Add Student",
                            icon: "person.badge.plus",
                            style: .primary,
                            isLoading: stateModel.isLoading,
                            action: {
                                Task {
                                    await stateModel.addStudent { student in
                                        onStudentAdded(student)
                                        dismiss()
                                    }
                                }
                            }
                        )
                        .disabled(stateModel.isLoading || !stateModel.isFormValid)
                        .opacity(stateModel.isFormValid ? 1.0 : 0.7)
                        .animation(.easeInOut(duration: 0.2), value: stateModel.isFormValid)
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationTitle("Add Student")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $stateModel.showingInterestPicker) {
            InterestSelectionView(
                selectedInterests: $stateModel.interests,
                onDismiss: {
                    stateModel.hideInterestPicker()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $stateModel.showingHobbyPicker) {
            HobbySelectionView(
                selectedHobbies: $stateModel.hobbies,
                onDismiss: {
                    stateModel.hideHobbyPicker()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Interest Selection View
struct InterestSelectionView: View {
    @Binding var selectedInterests: [Interest]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(Interest.sampleInterests) { interest in
                            InterestPickerCard(
                                interest: interest,
                                isSelected: selectedInterests.contains(interest),
                                onTap: { toggleInterest(interest) }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Interests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func toggleInterest(_ interest: Interest) {
        if selectedInterests.contains(interest) {
            selectedInterests.removeAll { $0.id == interest.id }
        } else {
            selectedInterests.append(interest)
        }
    }
}

// MARK: - Hobby Selection View
struct HobbySelectionView: View {
    @Binding var selectedHobbies: [Hobby]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 16) {
                        ForEach(Hobby.sampleHobbies) { hobby in
                            HobbyPickerCard(
                                hobby: hobby,
                                isSelected: selectedHobbies.contains(hobby),
                                onTap: { toggleHobby(hobby) }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Select Hobbies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func toggleHobby(_ hobby: Hobby) {
        if selectedHobbies.contains(hobby) {
            selectedHobbies.removeAll { $0.id == hobby.id }
        } else {
            selectedHobbies.append(hobby)
        }
    }
}

// MARK: - Picker Cards
struct InterestPickerCard: View {
    let interest: Interest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: interest.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .tmiSecondary : .white.opacity(0.7))
                
                Text(interest.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.tmiSecondary : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

struct HobbyPickerCard: View {
    let hobby: Hobby
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: hobby.iconName)
                    .font(.system(size: 30))
                    .foregroundColor(isSelected ? .tmiSecondary : .white.opacity(0.7))
                
                Text(hobby.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(isSelected ? 0.1 : 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.tmiSecondary : Color.white.opacity(0.2),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

