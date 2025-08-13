//
//  Search.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import SwiftUI

struct SearchBarTextFieldStyle: ViewModifier {
    @Binding var isEditing: Bool
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(.black)
            .padding(7)
            .padding(.horizontal, 25)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                HStack {
                    if isEditing {
                        Button(action: {
                            // This should be handled outside as there is no searchText here
                        }) {
//                            Spacer()
//
//                            Image(systemName: "multiply.circle.fill")
//                                .foregroundColor(.gray)
//                                .padding([.leading, .horizontal], 8)
                        }
                    }
                }
            )
    }
}

struct CustomSearchBar: View {
    @Binding var searchText: String
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var placeholder: String
    
    @Binding var isEditing: Bool
    @Binding var showCancelButton: Bool
    
    var body: some View {
        HStack {
            TextField(placeholder, text: $searchText, onEditingChanged: { editing in
                isEditing = editing
                showCancelButton = true
            }, onCommit: {
                onCommit?()
            })
            .modifier(SearchBarTextFieldStyle(isEditing: $isEditing))

            if showCancelButton {
                Button("Cancel") {
                    UIApplication.shared.endEditing(true)
                    searchText = ""
                    showCancelButton = false
                    isEditing = false
                    onCancel?()
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .animation(.default, value: showCancelButton)
    }
}

struct DropdownListView<Item: Identifiable & Codable & CustomStringConvertible>: View where Item: Equatable {
    var items: [Item]
    var query: String
    @Binding var selectedItem: Item?

    private var filteredItems: [Item] {
        guard !query.isEmpty else { return items }

        let relevanceThreshold = 10
        return items
            .map { item -> (item: Item, score: Int) in
                (item, SearchScorer.score(item: item, with: query))
            }
            .filter { $0.score > relevanceThreshold }
            .sorted { $0.score > $1.score }
            .map { $0.item }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(filteredItems) { item in
                    Button(action: {
                        self.selectedItem = item
                    }) {
                        HStack {
                            Text(item.description)
                            Spacer()
                            if selectedItem?.id == item.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(5)
                        .shadow(radius: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(maxHeight: 200)
    }
}


struct SearchScorer {
    static func score<Item: CustomStringConvertible>(item: Item, with query: String) -> Int {
        let normalizedQuery = query.lowercased()
        let normalizedDescription = "\(item)".lowercased()

        var score = 0
        if normalizedDescription.contains(normalizedQuery) {
            score += 50
        }

        let queryWords = normalizedQuery.split(separator: " ")
        let descriptionWords = normalizedDescription.split(separator: " ")
        let matchingWordsCount = queryWords.filter(descriptionWords.contains).count
        score += matchingWordsCount * 30

        var sequenceMatchScore = 0
        var lastIndex = normalizedDescription.startIndex
        for char in normalizedQuery {
            if let index = normalizedDescription[lastIndex...].firstIndex(of: char) {
                sequenceMatchScore += 1
                lastIndex = index
            } else {
                sequenceMatchScore -= 1
            }
        }
        score += sequenceMatchScore

        return score
    }
}