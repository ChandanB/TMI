import SwiftUI
import FirebaseFirestore

struct StudentListView: View {
    @StateObject private var viewModel = StudentListViewModel()
    @State private var searchText = ""
    @State private var showingAddStudent = false
    @State private var selectedFilterOption: FilterOption = .all
    @State private var showingFilterSheet = false
    @State private var selectedStudent: Student?
    
    enum FilterOption: String, CaseIterable, Identifiable {
        var id: String { self.rawValue }
        
        case all = "All"
        case active = "Active TMI"
        case inactive = "Inactive TMI"
        case highEngagement = "High Engagement"
        case lowEngagement = "Low Engagement"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchAndFilterBar
                studentGrid
                quickActionBar
            }
            .background(Color.tmiBackground)
            .navigationTitle("Students")
            .sheet(isPresented: $showingAddStudent) {
                AddStudentView()
            }
            .sheet(isPresented: $showingFilterSheet) {
                StudentListFilterView(selectedOption: $selectedFilterOption)
            }
            .sheet(item: $selectedStudent) { student in
                StudentDetailView(student: student)
            }
            .onAppear {
                viewModel.fetchStudents()
            }
        }
    }
    
    private var searchAndFilterBar: some View {
        HStack {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search students", text: $searchText)
                    .autocorrectionDisabled()
            }
            .padding(8)
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            
            Button(action: { showingFilterSheet = true }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.tmiPrimary)
                    .font(.title2)
            }
        }
        .padding()
    }
    
    private var studentGrid: some View {
        ScrollView {
            if viewModel.students.isEmpty {
                Text("No students available.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 20) {
                    ForEach(filteredStudents) { student in
                        StudentCard(student: student)
                            .onTapGesture {
                                selectedStudent = student
                            }
                    }
                }
                .padding()
            }
        }
    }
    
    private var quickActionBar: some View {
        HStack {
            Button(action: { showingAddStudent = true }) {
                Label("Add Student", systemImage: "person.badge.plus")
            }
            .buttonStyle(QuickActionButtonStyle())
            
            Button(action: { /* Implement bulk action */ }) {
                Label("Bulk Action", systemImage: "square.and.pencil")
            }
            .buttonStyle(QuickActionButtonStyle())
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15, corners: [.topLeft, .topRight])
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
    }
    
    private var filteredStudents: [Student] {
        viewModel.students.filter { student in
            (searchText.isEmpty || student.name.localizedCaseInsensitiveContains(searchText)) &&
            (selectedFilterOption == .all || matchesFilter(student: student, filter: selectedFilterOption))
        }
    }
    
    private func matchesFilter(student: Student, filter: FilterOption) -> Bool {
        switch filter {
        case .all:
            return true
        case .active:
            return student.tmiPlans?.isEmpty == false
        case .inactive:
            return student.tmiPlans?.isEmpty ?? true
        case .highEngagement:
            return student.engagementScore >= 0.7
        case .lowEngagement:
            return student.engagementScore < 0.3
        }
    }
}

#Preview {
    StudentListView()
}
