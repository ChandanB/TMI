//
//  SurveysView.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct FormsAndSurveysView: View {
    @State private var surveys: [Survey] = [Survey.sampleSurvey]
    @State private var showingAddSurvey = false
    @State private var selectedFilter: SurveyFilter = .all
    
    enum SurveyFilter: String, CaseIterable {
        case all = "All"
        case completed = "Completed"
        case pending = "Pending"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterPicker
                
                List {
                    ForEach(filteredSurveys) { survey in
                        NavigationLink(destination: SurveyDetailView(survey: survey)) {
                            SurveyCard(survey: survey)
                        }
                        .listRowSeparator(.hidden)
                    }
                    .onDelete(perform: deleteSurveys)
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Surveys")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddSurvey = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.tmiPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddSurvey) {
                AddSurveyView(surveys: $surveys)
            }
        }
        .onAppear(perform: loadSurveys)
    }
    
    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(SurveyFilter.allCases, id: \.self) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
    }
    
    private var filteredSurveys: [Survey] {
        switch selectedFilter {
        case .all:
            return surveys
        case .completed:
            return surveys.filter { $0.completed }
        case .pending:
            return surveys.filter { !$0.completed }
        }
    }
    
    private func loadSurveys() {
        // TODO: Implement survey loading logic
    }
    
    private func deleteSurveys(at offsets: IndexSet) {
        surveys.remove(atOffsets: offsets)
        // TODO: Implement survey deletion logic
    }
}

struct SurveyCard: View {
    let survey: Survey
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(survey.title)
                    .font(.headline)
                Spacer()
                Image(systemName: survey.completed ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(survey.completed ? .green : .gray)
            }
            
            Text(survey.surveyType.rawValue.capitalized)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Label("\(survey.questions.count)", systemImage: "list.bullet")
                Spacer()
                Text(survey.date, style: .date)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.tmiBackground)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct SurveyRow: View {
    let survey: Survey
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(survey.title)
                .font(.headline)
            Text("Type: \(survey.surveyType.rawValue.capitalized)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Questions: \(survey.questions.count)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct SurveyDetailView: View {
    let survey: Survey
    
    var body: some View {
        List {
            ForEach(survey.questions) { question in
                VStack(alignment: .leading) {
                    Text(question.text)
                        .font(.headline)
                    switch question.answerType {
                    case .text:
                        Text("Text Answer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    case .multipleChoice:
                        ForEach(question.options ?? [], id: \.self) { option in
                            Text("• \(option)")
                                .font(.subheadline)
                        }
                    case .scale:
                        Text("Scale: 1-5")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle(survey.title)
    }
}

struct AddSurveyView: View {
    @Binding var surveys: [Survey]
    @State private var title = ""
    @State private var surveyType: Survey.SurveyType = .interests
    @State private var questions: [Survey.Question] = []
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack {
                        TextField("Survey Title", text: $title)
                        Picker("Survey Type", selection: $surveyType) {
                            ForEach(Survey.SurveyType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                    }
                } header: {
                    Text("Survey Details")
                }
                
                Section(header: Text("Questions")) {
                    ForEach(questions.indices, id: \.self) { index in
                        QuestionRow(question: $questions[index])
                    }
                    .onDelete(perform: deleteQuestion)
                    
                    Button("Add Question") {
                        questions.append(Survey.Question(id: UUID().uuidString, text: "", answerType: .text))
                    }
                }
            }
            .navigationTitle("Add Survey")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSurvey()
                    }
                }
            }
        }
    }
    
    private func deleteQuestion(at offsets: IndexSet) {
        questions.remove(atOffsets: offsets)
    }
    
    private func saveSurvey() {
        let newSurvey = Survey(title: title, studentId: "TODO", date: Date(), questions: questions, completed: false, surveyType: surveyType)
        surveys.append(newSurvey)
        presentationMode.wrappedValue.dismiss()
    }
}

struct QuestionRow: View {
    @Binding var question: Survey.Question
    
    var body: some View {
        VStack {
            TextField("Question", text: $question.text)
            Picker("Answer Type", selection: $question.answerType) {
                Text("Text").tag(Survey.Question.AnswerType.text)
                Text("Multiple Choice").tag(Survey.Question.AnswerType.multipleChoice)
                Text("Scale").tag(Survey.Question.AnswerType.scale)
            }
            if question.answerType == .multipleChoice {
                ForEach(question.options?.indices ?? [].indices, id: \.self) { index in
                    TextField("Option \(index + 1)", text: Binding(
                        get: { question.options?[index] ?? "" },
                        set: { question.options?[index] = $0 }
                    ))
                }
                Button("Add Option") {
                    question.options = (question.options ?? []) + [""]
                }
            }
        }
    }
}

#Preview {
    FormsAndSurveysView()
}
