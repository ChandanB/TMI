// StudentDetailView.swift

import SwiftUI

struct StudentDetailView: View {
    let student: Student
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let avatarImage = studentAvatar {
                    avatarImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.tmiPrimary, lineWidth: 4))
                        .shadow(radius: 5)
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 150, height: 150)
                        .foregroundColor(.gray)
                        .overlay(Circle().stroke(Color.tmiPrimary, lineWidth: 4))
                        .shadow(radius: 5)
                }
                
                Text(student.name)
                    .font(.largeTitle)
                    .bold()
                
                Text("Grade: \(student.grade)")
                    .font(.title2)
                
                Text("Date of Birth: \(formattedDate)")
                    .font(.title3)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Interests:")
                        .font(.headline)
                    if student.interests.isEmpty {
                        Text("No interests available.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(student.interests, id: \.id) { interest in
                            Text("• \(interest.name)")
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Text("Hobbies:")
                        .font(.headline)
                        .padding(.top)
                    if student.hobbies.isEmpty {
                        Text("No hobbies available.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(student.hobbies, id: \.id) { hobby in
                            Text("• \(hobby.name)")
                                .foregroundColor(.primary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Student Details")
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: student.dateOfBirth)
    }
    
    private var studentAvatar: Image? {
        // Implement avatar image retrieval logic here.
        return nil
    }
}

#Preview {
    StudentDetailView(student: Student.sampleStudent)
}
