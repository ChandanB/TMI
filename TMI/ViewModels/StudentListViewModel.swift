//
//  StudentListViewModel.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import Foundation
import FirebaseFirestore

class StudentListViewModel: ObservableObject {
    @Published var students: [Student] = []
    private var db = Firestore.firestore()
    
    func fetchStudents() {
        db.collection("students").getDocuments { (querySnapshot, error) in
            if let error = error {
                print("Error getting students: \(error.localizedDescription)")
            } else {
                self.students = querySnapshot?.documents.compactMap { document -> Student? in
                    try? document.data(as: Student.self)
                } ?? []
            }
        }
    }
    
    func addStudent(_ student: Student) {
        do {
            let _ = try db.collection("students").addDocument(from: student)
            fetchStudents() // Refresh the list after adding
        } catch {
            print("Error adding student: \(error.localizedDescription)")
        }
    }
    
    func deleteStudent(_ student: Student) {
        guard let id = student.id else { return }
        db.collection("students").document(id).delete { error in
            if let error = error {
                print("Error deleting student: \(error.localizedDescription)")
            } else {
                self.fetchStudents() // Refresh the list after deleting
            }
        }
    }
}
