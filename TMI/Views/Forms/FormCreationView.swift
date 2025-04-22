//
//  FormCreationView.swift
//  CAMP APP
//
//  Created by Chandan Brown on 4/12/24.
//

import SwiftUI
import FirebaseFirestore
import Observation

@Observable
class FormCreationViewModel {
    var name: String = ""
    var description: String = ""
    var isActive: Bool = true
    
    func createTemplate(completion: @escaping (Bool, Error?) -> Void) {
        let newTemplateData: [String: Any] = [
            "name": name,
            "description": description,
            "isActive": isActive,
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date()),
            // Add additional fields as necessary
        ]
        
        FIRESTORE_DATABASE.collection("formTemplates").addDocument(data: newTemplateData) { error in
            if let error = error {
                completion(false, error)
            } else {
                completion(true, nil)
            }
        }
    }
}


#Preview {
    FormCreationView()
}
