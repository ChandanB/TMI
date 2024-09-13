import SwiftUI
import FirebaseFirestore

struct AddStudentView: View {
    @EnvironmentObject private var firestoreContext: FirestoreContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var name = ""
    @State private var grade = ""
    @State private var dateOfBirth = Date()
    @State private var interests: [Interest] = []
    @State private var avatar: Image?
    @State private var isShowingImagePicker = false
    @State private var inputImage: UIImage?
    @State private var currentStep = 0
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let steps = ["Basic Info", "Interests", "Avatar"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                stepIndicator
                
                TabView(selection: $currentStep) {
                    basicInfoView.tag(0)
                    interestsView.tag(1)
                    avatarView.tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                                
                navigationButtons
                
                if sizeClass == .regular {
                    Spacer(minLength: 150)
                }
            }
            .background(Color.tmiBackground.ignoresSafeArea())
            .navigationTitle("Add New Student")
            .navigationBarItems(leading: Button("Cancel") { dismiss() })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Missing Information"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private var stepIndicator: some View {
        HStack {
            ForEach(0..<steps.count, id: \.self) { index in
                Circle()
                    .fill(index <= currentStep ? Color.tmiPrimary : Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                if index < steps.count - 1 {
                    Rectangle()
                        .fill(index < currentStep ? Color.tmiPrimary : Color.gray.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
        .padding(.horizontal)
    }

    private var basicInfoView: some View {
        VStack(spacing: 20) {
            FloatingTextField(placeholder: "Full Name", text: $name)
            FloatingTextField(placeholder: "Grade", text: $grade)
            DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                .datePickerStyle(GraphicalDatePickerStyle())
                .padding()
                .background(Color.tmiSecondary.opacity(0.1))
                .cornerRadius(10)
        }
        .padding()
    }

    private var interestsView: some View {
        VStack(spacing: 20) {
            Text("What are the student's interests?")
                .font(.headline)

            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 10) {
                    ForEach(Interest.sampleInterests) { interest in
                        InterestButton(interest: interest, isSelected: interests.contains(interest)) {
                            if interests.contains(interest) {
                                interests.removeAll { $0 == interest }
                            } else {
                                interests.append(interest)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .padding()
    }

    private var avatarView: some View {
        VStack(spacing: 20) {
            Text("Add a profile picture")
                .font(.headline)

            if let avatar = avatar {
                avatar
                    .resizable()
                    .scaledToFill()
                    .frame(width: 200, height: 200)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.tmiPrimary, lineWidth: 4))
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .foregroundColor(.gray)
            }

            Button("Choose Photo") {
                isShowingImagePicker = true
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .sheet(isPresented: $isShowingImagePicker, onDismiss: loadImage) {
            ImagePicker(image: $inputImage)
        }
    }

    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Back") {
                    currentStep -= 1
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Spacer()
            
            if currentStep < steps.count - 1 {
                Button("Next") {
                    if validateCurrentStep() {
                        currentStep += 1
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Save") {
                    if validateCurrentStep() {
                        addStudent()
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding()
    }

    private func addStudent() {
            let newStudent = Student(
                name: name,
                grade: grade,
                dateOfBirth: dateOfBirth,
                interests: interests,
                hobbies: []
            )
            // Save the new student to Firestore or local storage
        }

    private func loadImage() {
        guard let inputImage = inputImage else { return }
        avatar = Image(uiImage: inputImage)
    }

    @State private var showAlert = false
    @State private var alertMessage = ""

    private func validateCurrentStep() -> Bool {
        switch currentStep {
        case 0:
            if name.isEmpty || grade.isEmpty {
                alertMessage = "Please fill in all fields."
                showAlert = true
                return false
            }
        case 1:
            if interests.isEmpty {
                alertMessage = "Please select at least one interest."
                showAlert = true
                return false
            }
        default:
            break
        }
        return true
    }
}

struct FloatingTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .leading) {
            Text(placeholder)
                .foregroundColor(text.isEmpty ? Color.gray : Color.tmiPrimary)
                .offset(y: text.isEmpty ? 0 : -25)
                .scaleEffect(text.isEmpty ? 1 : 0.8, anchor: .leading)
            TextField("", text: $text)
        }
        .padding(.top, 15)
        .animation(.default, value: text)
    }
}

struct InterestButton: View {
    let interest: Interest
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(interest.name)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Color.tmiPrimary : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(15)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.tmiPrimary)
            .foregroundColor(.white)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.primary)
            .cornerRadius(10)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

 #Preview {
     AddStudentView()
 }
