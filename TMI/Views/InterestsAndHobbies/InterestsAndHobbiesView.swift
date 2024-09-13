// InterestsAndHobbiesView.swift

import SwiftUI

enum InterestsAndHobbiesItemType: String, CaseIterable, Identifiable {
    case interest = "Interest"
    case hobby = "Hobby"
    
    var id: String { self.rawValue }
}

struct InterestsAndHobbiesView: View {
    @State var interests: [Interest]
    @State var hobbies: [Hobby]
    @State private var showingAddSheet = false
    @State private var newItemType: InterestsAndHobbiesItemType = .interest
    @State private var newItemName = ""
    @State private var searchText = ""
    @State private var selectedSegment: Segment = .interests
    
    enum Segment: String, CaseIterable, Identifiable {
        case interests = "Interests"
        case hobbies = "Hobbies"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerView
                    searchBar
                    segmentedControl
                    itemsGridView
                }
                .padding()
            }
            .background(Color.tmiBackground.ignoresSafeArea())
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAddSheet) {
                AddItemView(itemType: $newItemType, itemName: $newItemName, onSave: addItem)
            }
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Interests & Hobbies")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
                Text("Explore and manage your interests and hobbies")
                    .font(.subheadline)
                    .foregroundColor(.tmiSecondary)
            }
            Spacer()
            Button(action: { showingAddSheet = true }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.tmiPrimary)
            }
            .accessibilityLabel("Add New Item")
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.tmiSecondary)
            TextField("Search", text: $searchText)
                .autocorrectionDisabled()
        }
        .padding(10)
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(10)
    }
    
    // MARK: - Segmented Control
    
    private var segmentedControl: some View {
        Picker("Segment", selection: $selectedSegment) {
            ForEach(Segment.allCases) { segment in
                Text(segment.rawValue).tag(segment)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.vertical, 5)
    }
    
    // MARK: - Items Grid View
    
    private var itemsGridView: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 20) {
            if selectedSegment == .interests {
                ForEach(filteredInterests) { interest in
                    NavigationLink(destination: InterestDetailView(interest: interest)) {
                        ItemCardView(title: interest.name)
                    }
                }
                .onDelete(perform: deleteInterests)
            } else {
                ForEach(filteredHobbies) { hobby in
                    NavigationLink(destination: HobbyDetailView(hobby: hobby)) {
                        ItemCardView(title: hobby.name)
                    }
                }
                .onDelete(perform: deleteHobbies)
            }
        }
    }
    
    // MARK: - Filtering
    
    private var filteredInterests: [Interest] {
        interests.filter { $0.name.localizedCaseInsensitiveContains(searchText) || searchText.isEmpty }
    }
    
    private var filteredHobbies: [Hobby] {
        hobbies.filter { $0.name.localizedCaseInsensitiveContains(searchText) || searchText.isEmpty }
    }
    
    // MARK: - Data Manipulation
    
    private func addItem() {
        withAnimation {
            if newItemType == .interest {
                let newInterest = Interest(id: UUID().uuidString, name: newItemName, details: nil, relatedStudents: nil)
                interests.append(newInterest)
            } else {
                let newHobby = Hobby(id: UUID().uuidString, name: newItemName, details: nil, relatedStudents: nil)
                hobbies.append(newHobby)
            }
            newItemName = ""
            showingAddSheet = false
        }
    }
    
    private func deleteInterests(offsets: IndexSet) {
        withAnimation {
            interests.remove(atOffsets: offsets)
        }
    }
    
    private func deleteHobbies(offsets: IndexSet) {
        withAnimation {
            hobbies.remove(atOffsets: offsets)
        }
    }
}

// MARK: - Custom Components

struct ItemCardView: View {
    let title: String
    
    var body: some View {
        VStack {
            Text(title.prefix(1))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.tmiPrimary)
                .clipShape(Circle())
            
            Text(title)
                .font(.headline)
                .foregroundColor(.tmiText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.tmiSecondary.opacity(0.1))
        .cornerRadius(15)
    }
}

struct AddItemView: View {
    @Binding var itemType: InterestsAndHobbiesItemType
    @Binding var itemName: String
    let onSave: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                headerView
                formView
                Spacer()
                saveButton
            }
            .padding()
            .background(Color.tmiBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Add New Item")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.tmiPrimary)
                Text("Enter the details below")
                    .font(.title3)
                    .foregroundColor(.tmiSecondary)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(.tmiPrimary)
            }
        }
    }
    
    private var formView: some View {
        VStack(spacing: 20) {
            Picker("Type", selection: $itemType) {
                ForEach(InterestsAndHobbiesItemType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("Name", text: $itemName)
                .padding()
                .background(Color.tmiSecondary.opacity(0.1))
                .cornerRadius(10)
        }
        .padding(.top)
    }
    
    private var saveButton: some View {
        Button(action: {
            onSave()
            dismiss()
        }) {
            HStack {
                Spacer()
                Text("Save")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(itemName.isEmpty ? Color.gray : Color.tmiPrimary)
            .cornerRadius(10)
        }
        .disabled(itemName.isEmpty)
    }
}

struct InterestDetailView: View {
    let interest: Interest
    
    var body: some View {
        VStack(spacing: 20) {
            Text(interest.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.tmiPrimary)
            Text("Details about this interest will be displayed here.")
                .font(.body)
                .foregroundColor(.tmiText)
            Spacer()
        }
        .padding()
        .background(Color.tmiBackground.ignoresSafeArea())
        .navigationTitle("Interest Details")
    }
}

struct HobbyDetailView: View {
    let hobby: Hobby
    
    var body: some View {
        VStack(spacing: 20) {
            Text(hobby.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.tmiPrimary)
            Text("Details about this hobby will be displayed here.")
                .font(.body)
                .foregroundColor(.tmiText)
            Spacer()
        }
        .padding()
        .background(Color.tmiBackground.ignoresSafeArea())
        .navigationTitle("Hobby Details")
    }
}

#Preview {
    InterestsAndHobbiesView(interests: Interest.sampleInterests, hobbies: Hobby.sampleHobbies)
}
