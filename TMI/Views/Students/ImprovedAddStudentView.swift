//
//  ImprovedAddStudentView.swift
//  TMI
//
//  Created by Chandan Brown on 8/7/25.
//

import SwiftUI
import Observation

struct ImprovedAddStudentView: View {
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
    }
}

