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
    @Environment(\.simpleAuthStateModel) private var authStateModel
    @State private var stateModel: AddStudentStateModel?
    
    let student: Student?
    let onStudentAdded: () -> Void
    
    init(student: Student? = nil, onStudentAdded: @escaping () -> Void) {
        self.student = student
        self.onStudentAdded = onStudentAdded
    }
    
    var body: some View {
        Group {
            if let currentStateModel = stateModel {
                ZStack {
                    // Background
                    TMIBackgroundView(variant: .default)
                        .ignoresSafeArea()
                    
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Enhanced Header
                            VStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(.tmiSecondary.opacity(0.2))
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: currentStateModel.isEditing ? "person.fill.checkmark" : "person.badge.plus")
                                        .font(.system(size: 36, weight: .medium))
                                        .foregroundColor(.tmiSecondary)
                                }
                                .padding(.top, 10)
                                
                                VStack(spacing: 8) {
                                    Text(currentStateModel.isEditing ? "Edit Student" : "Add New Student")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(currentStateModel.isEditing ? "Update the student's information below" : "Let's get to know this student better")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white.opacity(0.8))
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 30)
                                }
                            }
                            .padding(.bottom, 20)
                            
                            // Basic Information Section
                            VStack(spacing: 16) {
                                TMISectionHeader(title: "Basic Information", icon: "person.text.rectangle")
                                
                                TMIGlassCard(style: .form) {
                                    VStack(spacing: 18) {
                                        TMITextField(
                                            icon: "person.fill",
                                            placeholder: "Student Name",
                                            text: Binding(get: { currentStateModel.name }, set: { currentStateModel.name = $0 })
                                        )
                                        
                                        TMITextField(
                                            icon: "number.square",
                                            placeholder: "Grade Level",
                                            text: Binding(get: { currentStateModel.grade }, set: { currentStateModel.grade = $0 })
                                        )
                                        
                                        TMITextField(
                                            icon: "barcode",
                                            placeholder: "Student ID (optional)",
                                            text: Binding(get: { currentStateModel.studentID }, set: { currentStateModel.studentID = $0 })
                                        )
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label("Date of Birth", systemImage: "calendar")
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.white.opacity(0.9))
                                            
                                            DatePicker(
                                                "Date of Birth",
                                                selection: Binding(get: { currentStateModel.dateOfBirth }, set: { currentStateModel.dateOfBirth = $0 }),
                                                in: Calendar.current.date(byAdding: .year, value: -25, to: Date())!...Calendar.current.date(byAdding: .year, value: -3, to: Date())!,
                                                displayedComponents: .date
                                            )
                                            .datePickerStyle(.compact)
                                            .accentColor(.tmiSecondary)
                                            .labelsHidden()
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            
                            // Personal Interests Section
                            VStack(spacing: 16) {
                                TMISectionHeader(title: "Personal Interests", icon: "heart.circle")
                                
                                VStack(spacing: 16) {
                                    TMISelectionSection(
                                        title: "Interests",
                                        icon: "heart.fill",
                                        count: currentStateModel.interests.count,
                                        selectedItems: currentStateModel.interests.map { $0.name },
                                        placeholder: "Add interests to help personalize learning",
                                        onTap: { currentStateModel.showingInterestPicker = true }
                                    )
                                    
                                    TMISelectionSection(
                                        title: "Hobbies",
                                        icon: "gamecontroller.fill",
                                        count: currentStateModel.hobbies.count,
                                        selectedItems: currentStateModel.hobbies.map { $0.name },
                                        placeholder: "Add hobbies to connect learning to their passions",
                                        onTap: { currentStateModel.showingHobbyPicker = true }
                                    )
                                }
                            }
                            
                            // Error message
                            if let errorMessage = currentStateModel.errorMessage {
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
                                text: currentStateModel.isEditing ? "Save Changes" : "Add Student",
                                icon: currentStateModel.isEditing ? "person.fill.checkmark" : "person.badge.plus",
                                style: .primary,
                                isLoading: currentStateModel.isLoading,
                                action: {
                                    Task {
                                        if await currentStateModel.saveStudent() != nil {
                                            onStudentAdded()
                                            dismiss()
                                        }
                                    }
                                }
                            )
                            .disabled(currentStateModel.isLoading || !currentStateModel.isFormValid)
                            .opacity(currentStateModel.isFormValid ? 1.0 : 0.7)
                            .animation(.easeInOut(duration: 0.2), value: currentStateModel.isFormValid)
                            
                            Spacer(minLength: 50)
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .navigationTitle(currentStateModel.isEditing ? "Edit Student" : "Add Student")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
                .preferredColorScheme(.dark)
                .sheet(isPresented: Binding(get: { currentStateModel.showingInterestPicker }, set: { currentStateModel.showingInterestPicker = $0 })) {
                    InterestSelectionView(
                        selectedInterests: Binding(get: { currentStateModel.interests }, set: { currentStateModel.interests = $0 }),
                        onDismiss: {
                            currentStateModel.showingInterestPicker = false
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
                .sheet(isPresented: Binding(get: { currentStateModel.showingHobbyPicker }, set: { currentStateModel.showingHobbyPicker = $0 })) {
                    HobbySelectionView(
                        selectedHobbies: Binding(get: { currentStateModel.hobbies }, set: { currentStateModel.hobbies = $0 }),
                        onDismiss: {
                            currentStateModel.showingHobbyPicker = false
                        }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            } else {
                ProgressView()
                    .onAppear {
                        stateModel = AddStudentStateModel(student: student, currentSchool: authStateModel.currentUser?.institutionID ?? "")
                    }
            }
        }
    }
}

// MARK: - Interest Selection View
struct InterestSelectionView: View {
    @Binding var selectedInterests: [Interest]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredInterests: [Interest] {
        if searchText.isEmpty {
            return Interest.expandedSampleInterests
        } else {
            return Interest.expandedSampleInterests.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header with selection count
                    TMIGlassCard(style: .form) {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.tmiSecondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Select Interests")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(selectedInterests.count) selected")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                            }
                            
                            // Search bar
                            TMITextField(
                                icon: "magnifyingglass",
                                placeholder: "Search interests...",
                                text: $searchText
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Selected interests summary
                    if !selectedInterests.isEmpty {
                        TMIGlassCard(style: .form) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Interests")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                TMISelectedItemsView(items: selectedInterests.map { $0.name })
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Interests grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 140, maximum: 180))
                        ], spacing: 16) {
                            ForEach(filteredInterests) { interest in
                                InterestPickerCard(
                                    interest: interest,
                                    isSelected: selectedInterests.contains(interest),
                                    onTap: { toggleInterest(interest) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(.tmiSecondary)
                    .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func toggleInterest(_ interest: Interest) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedInterests.contains(interest) {
                selectedInterests.removeAll { $0.id == interest.id }
            } else {
                selectedInterests.append(interest)
            }
        }
    }
}

// MARK: - Hobby Selection View
struct HobbySelectionView: View {
    @Binding var selectedHobbies: [Hobby]
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredHobbies: [Hobby] {
        if searchText.isEmpty {
            return Hobby.expandedSampleHobbies
        } else {
            return Hobby.expandedSampleHobbies.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                TMIBackgroundView(variant: .default)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header with selection count
                    TMIGlassCard(style: .form) {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.tmiSecondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Select Hobbies")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(selectedHobbies.count) selected")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                            }
                            
                            // Search bar
                            TMITextField(
                                icon: "magnifyingglass",
                                placeholder: "Search hobbies...",
                                text: $searchText
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Selected hobbies summary
                    if !selectedHobbies.isEmpty {
                        TMIGlassCard(style: .form) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Hobbies")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                
                                TMISelectedItemsView(items: selectedHobbies.map { $0.name })
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Hobbies grid
                    ScrollView {
                        LazyVGrid(columns: [
                            GridItem(.adaptive(minimum: 140, maximum: 180))
                        ], spacing: 16) {
                            ForEach(filteredHobbies) { hobby in
                                HobbyPickerCard(
                                    hobby: hobby,
                                    isSelected: selectedHobbies.contains(hobby),
                                    onTap: { toggleHobby(hobby) }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(.tmiSecondary)
                    .fontWeight(.semibold)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func toggleHobby(_ hobby: Hobby) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedHobbies.contains(hobby) {
                selectedHobbies.removeAll { $0.id == hobby.id }
            } else {
                selectedHobbies.append(hobby)
            }
        }
    }
}

// MARK: - Enhanced Components

/// Section header component for form organization
struct TMISectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.tmiSecondary)
            
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

/// Unified selection section component for interests, hobbies, etc.
struct TMISelectionSection: View {
    let title: String
    let icon: String
    let count: Int
    let selectedItems: [String]
    let placeholder: String
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with count
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.tmiSecondary)
                
                Text("\(title) (\(count))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Selection button with enhanced styling
            Button(action: onTap) {
                TMIGlassCard(style: .form) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            if selectedItems.isEmpty {
                                Text(placeholder)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                    .multilineTextAlignment(.leading)
                            } else {
                                // Show selected items as tags
                                TMISelectedItemsView(items: selectedItems)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.tmiSecondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

/// Display selected items as styled tags
struct TMISelectedItemsView: View {
    let items: [String]
    let maxItemsToShow = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First row of tags
            let displayItems = Array(items.prefix(maxItemsToShow))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                ForEach(displayItems, id: \.self) { item in
                    TMISelectionTag(text: item)
                }
            }
            
            // Show count if there are more items
            if items.count > maxItemsToShow {
                Text("+ \(items.count - maxItemsToShow) more")
                    .font(.system(size: 12))
                    .foregroundColor(.tmiSecondary)
                    .padding(.top, 2)
            }
        }
    }
}

/// Individual selection tag
struct TMISelectionTag: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.tmiSecondary.opacity(0.2))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.tmiSecondary.opacity(0.4), lineWidth: 1)
                    )
            )
            .lineLimit(1)
    }
}

// MARK: - Unified Picker Card

/// Generic picker card that works for both interests and hobbies
struct TMIPickerCard<T: Identifiable & Equatable>: View {
    let item: T
    let isSelected: Bool
    let onTap: () -> Void
    let iconName: String
    let displayName: String
    
    var body: some View {
        Button(action: onTap) {
            TMIGlassCard(style: .form) {
                VStack(spacing: 12) {
                    // Icon with enhanced styling
                    ZStack {
                        Circle()
                            .fill(.tmiSecondary.opacity(isSelected ? 0.2 : 0.1))
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: iconName)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(isSelected ? .tmiSecondary : .white.opacity(0.8))
                    }
                    
                    Text(displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(minHeight: 36) // Consistent height
                    
                    // Selection indicator
                    if isSelected {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.tmiSecondary)
                            
                            Text("Selected")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.tmiSecondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.tmiSecondary.opacity(0.1))
                        )
                    }
                }
                .padding(.vertical, 8)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? .tmiSecondary : .clear,
                        lineWidth: 2
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Updated Picker Cards using unified component

struct InterestPickerCard: View {
    let interest: Interest
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        TMIPickerCard(
            item: interest,
            isSelected: isSelected,
            onTap: onTap,
            iconName: interest.iconName,
            displayName: interest.name
        )
    }
}

struct HobbyPickerCard: View {
    let hobby: Hobby
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        TMIPickerCard(
            item: hobby,
            isSelected: isSelected,
            onTap: onTap,
            iconName: hobby.iconName,
            displayName: hobby.name
        )
    }
}

