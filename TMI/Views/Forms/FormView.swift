//

import SwiftUI
import SDWebImageSwiftUI
import Combine
import Observation

// MARK: – Environment Key
extension EnvironmentValues {
    @Entry var dynamicFormStateModel: DynamicFormStateModel = .init()
}

// MARK: – State Model

@Observable
final class DynamicFormStateModel: BaseStateModel<FormTemplate, IdentifiableError> {
  // MARK: – UI State Keys
  private enum Keys {
    static let sections    = "formSections"
    static let data        = "formData"
    static let isSubmitting = "isSubmitting"
    static let showPicker  = "showDocumentPicker"
  }

  // MARK: – Computed UI Properties

  /// Holds our per‑field form data
  var formData: [String: AnyCodable] {
    get { ui.get(Keys.data) ?? [:] }
    set { ui.set(Keys.data, value: newValue) }
  }

  /// Toggle to present UIDocumentPicker
  var showDocumentPicker: Bool {
    get { ui.get(Keys.showPicker) ?? false }
    set { ui.set(Keys.showPicker, value: newValue) }
  }

  /// Whether we're in the middle of form submission
  var isSubmitting: Bool {
    get { ui.get(Keys.isSubmitting) ?? false }
    set { ui.set(Keys.isSubmitting, value: newValue) }
  }

  /// The sections to render; defaults to a set of templates
  var formSections: [FormSection] {
    get { ui.get(Keys.sections) ?? [] }
    set { ui.set(Keys.sections, value: newValue) }
  }

  // MARK: – Initialization

  override init() {
    super.init()
    // load default sections
    formSections = [
      DefaultSectionTemplates.personalDetails,
      DefaultSectionTemplates.educationBackground,
      DefaultSectionTemplates.emergencyContact,
      DefaultSectionTemplates.fileUpload
    ]
  }

  // MARK: – Fetching a Template

  /// Load a form template from Firestore
  @MainActor
  func loadTemplate(id: String) async {
    // clear out old state & show loading spinner
    resetState()
    updateState(.loading)

    do {
      let template: FormTemplate = try await FIREBASE_MANAGER
        .fetchDocument(inCollection: .formTemplates, withId: id)
      updateState(.loaded(template))

      // Override sections if the template carries its own
        let secs = template.sections
      if !secs.isEmpty {
        formSections = secs
      }
    } catch {
      handleError(error)
    }
  }

  // MARK: – Submission

  /// Submit the filled‑in form back to your backend
  @MainActor
  func submit() async {
    guard case .loaded(let template) = state,
          let formId = template.id else {
      return
    }

    isSubmitting = true
    do {
      try await FIREBASE_MANAGER.handleFormSubmission(
        formId: formId,
        submissionData: formData
      )
      isSubmitting = false
      // Optionally reset formData or show a success UI
    } catch {
      isSubmitting = false
      handleError(error, userFriendlyMessage: "Failed to submit form")
    }
  }

  // MARK: – Helpers

  /// Update a single field in our `formData` dictionary
  func updateField(_ fieldId: String, to value: AnyCodable) {
    formData[fieldId] = value
  }

  /// Trigger the document picker
  func pickFile() {
    showDocumentPicker = true
  }
}

struct DynamicFormFieldView: View {
  let field: FormField
  @Environment(\.dynamicFormStateModel) private var stateModel

  var body: some View {
    VStack(alignment: .leading) {
      Text(field.label.uppercased())
        .font(.caption.weight(.semibold))

      fieldView
    }
  }

  @ViewBuilder
  private var fieldView: some View {
      if let id = field.id {
          switch field.type {
          case .text, .email, .phoneNumber:
            ZLHNTextField(
              placeholder: "Enter \(field.label)",
              text: binding(String.self, for: id)
            )

          case .longText:
            ZLHNMultilineTextField(
              placeholder: "Enter \(field.label)",
              text: binding(String.self, for: id),
              limit: 1000
            )

          case .number:
            ZLHNTextField(
              placeholder: "Enter \(field.label)",
              text: binding(String.self, for: id)
            )
            .keyboardType(.numberPad)

          case .date:
            DatePickerView(
              label: "Date",
              date: binding(Date.self, for: id),
              displayedComponents: .date
            )

          case .time:
            DatePickerView(
              label: "Time",
              date: binding(Date.self, for: id),
              displayedComponents: .hourAndMinute
            )

          case .dateTime:
            DatePickerView(
              label: field.label,
              date: binding(Date.self, for: id),
              displayedComponents: [.date, .hourAndMinute]
            )

          case .checkbox:
            Toggle(field.label, isOn: binding(Bool.self, for: id))

          case .multipleChoice:
            MultipleChoiceField(
              label: field.label,
              selectedOptions: binding([String].self, for: id),
              options: field.options ?? []
            )

          case .dropdown:
            DropdownField(
              label: field.label,
              selection: binding(String.self, for: id),
              options: field.options ?? []
            )
            
          case .rating:
            RatingField(
              label: field.label,
              rating: binding(Int.self, for: id),
              maxRating: 5
            )
            
          case .table:
            TableField(
              label: field.label,
              data: binding([String: String].self, for: id)
            )

          case .url:
            ZLHNTextField(
              placeholder: "Enter \(field.label)",
              text: binding(String.self, for: id)
            )
            .keyboardType(.URL)
            #if canImport(UIKit)
            .autocapitalization(.none)
            #endif

          case .file:
            Button {
              stateModel.pickFile()
            } label: {
              Label("Upload File", systemImage: "paperclip")
            }
            .buttonStyle(.plain)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)

          default:
            EmptyView()
      }
    }
  }

  // Helper to pull any type safely out of stateModel.formData
  private func binding<V: Codable>(_: V.Type, for key: String) -> Binding<V> {
    Binding<V>(
      get: {
        (stateModel.formData[key]?.value as? V)
        ?? (V.self == String.self ? "" as! V : Date() as! V)
      },
      set: { newValue in
        stateModel.formData[key] = AnyCodable(newValue)
      }
    )
  }
}

#Preview {
    DynamicFormView(templateId: "")
}

// MARK: - Dynamic Form View
struct DynamicFormView: View {
    // MARK: – Injected State Model
    @Environment(\.dynamicFormStateModel) private var stateModel
    @Environment(\.dismiss) private var dismiss

    // MARK: – Local UI State
    @State private var currentSection = 0
    @State private var showingSubmitConfirmation = false

    /// The Firestore template ID to load
    let templateId: String

    var body: some View {
        NavigationStack {
            ZStack {
                formBackgroundView

                VStack(spacing: 0) {
                    // Progress indicator
                    if stateModel.formSections.count > 1 {
                        ProgressIndicator(
                            current: currentSection + 1,
                            total: stateModel.formSections.count
                        )
                        .padding(.top, 20)
                        .padding(.horizontal, 20)
                    }

                    // Form content
                    formContent
                    
                    // Navigation buttons
                    if !stateModel.formSections.isEmpty {
                        navigationButtons
                    }
                }
            }
            .navigationTitle("Form Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .alert("Submit Form?", isPresented: $showingSubmitConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Submit") {
                    Task { await stateModel.submit() }
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to submit this form?")
            }
            .onAppear {
                // Load template only once
                if stateModel.value == nil {
                    Task { await stateModel.loadTemplate(id: templateId) }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Form Content
    
    private var formContent: some View {
        Group {
            if !stateModel.formSections.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        let section = stateModel.formSections[currentSection]

                        // Section title
                        Text(section.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)

                        // Section description
                        if let desc = section.description {
                            Text(desc)
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        // Fields
                        sectionFieldsView(section)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            } else {
                Spacer()
                Text("No form sections available")
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func sectionFieldsView(_ section: FormSection) -> some View {
        ForEach(section.fields) { field in
            DynamicFormFieldView(field: field)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentSection > 0 {
                Button {
                    withAnimation { currentSection -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                        Text("Previous")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .foregroundColor(.white)
                }
            }

            if currentSection < stateModel.formSections.count - 1 {
                Button {
                    withAnimation { currentSection += 1 }
                } label: {
                    HStack {
                        Text("Next")
                        Image(systemName: "arrow.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.tmiSecondary)
                        )
                        .foregroundColor(.white)
                }
            } else {
                Button {
                    showingSubmitConfirmation = true
                } label: {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.tmiSecondary)
                        )
                        .foregroundColor(.white)
                }
            }
        }
        .padding(20)
    }

    // MARK: – Background Gradient
    private var formBackgroundView: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.15),
                Color(red: 0.14, green: 0.14, blue: 0.25)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

// MARK: - Form Field Components


struct RatingField: View {
    let label: String
    @Binding var rating: Int
    let maxRating: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ForEach(1...maxRating, id: \.self) { star in
                    Button {
                        rating = star
                    } label: {
                        Image(systemName: star <= rating ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundColor(star <= rating ? .yellow : .white.opacity(0.4))
                    }
                }
                
                Spacer()
                
                if rating > 0 {
                    Text("\(rating)/\(maxRating)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
}

struct TableField: View {
    let label: String
    @Binding var data: [String: String]
    @State private var showingEditor = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingEditor = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edit \(label)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        
                        Text("\(data.count) entries")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(.tmiSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .sheet(isPresented: $showingEditor) {
            TableEditorView(data: $data, label: label)
        }
    }
}

struct TableEditorView: View {
    @Binding var data: [String: String]
    let label: String
    @Environment(\.dismiss) private var dismiss
    @State private var newKey = ""
    @State private var newValue = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Add new entry
                    VStack(spacing: 12) {
                        HStack {
                            ZLHNTextField(placeholder: "Key", text: $newKey)
                            ZLHNTextField(placeholder: "Value", text: $newValue)
                        }
                        
                        TMIButton(text: "Add Entry", style: .secondary) {
                            if !newKey.isEmpty && !newValue.isEmpty {
                                data[newKey] = newValue
                                newKey = ""
                                newValue = ""
                            }
                        }
                        .disabled(newKey.isEmpty || newValue.isEmpty)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    
                    // Existing entries
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(data.keys.sorted()), id: \.self) { key in
                                HStack {
                                    Text(key)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text(data[key] ?? "")
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Button {
                                        data.removeValue(forKey: key)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 12))
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.white.opacity(0.05))
                                )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct ProgressIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(current) of \(total)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                Text("\(Int(Double(current) / Double(total) * 100))%")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            ProgressView(value: Double(current), total: Double(total))
                .progressViewStyle(LinearProgressViewStyle(tint: .tmiSecondary))
                .scaleEffect(y: 0.5)
        }
    }
}
