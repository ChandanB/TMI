//
//  ButtonFactory.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/31/24.
//

import SwiftUI

struct ButtonFactoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                
                ZLHNSectionView(title: "SECTION", subtitle: "blah blah blah", actionTitle: "Do something?", foregroundColor: .white, backgroundColor: .black) {
                    Text("MESSAGE!")
                }
                ZLHNNavigationButton(label: nil, socialPlatform: "Facebook", action: {
                })
                
                ZLHNDescriptionButton(iconName: "person.wave.2.fill", title: "DOPE BUTTON", description: "With a cool description!")
                
                HStack {
                    JoinCampButton(isJoined: .constant(false)) {
                        print("Join")
                    }
                    
                    ApplyButton(isApplied: .constant(false)) {
                        print("Apply")
                    }
                }
                
                CustomButton(title: "Button", action: {
                    print("Button 1")
                }, foregroundColor: .white, backgroundColor: .tmiBackground)
                
                
            }
            .padding(.top)
        }
        
        
    }
}

struct BaseButtonStyle: ButtonStyle {
    var foregroundColor: Color
    var backgroundColor: Color
    var pressedScale: CGFloat = 0.96
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical)
            .frame(minWidth: 120)
            .frame(maxWidth: .infinity, maxHeight: 44)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(10)
            .padding(.horizontal, 4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut, value: configuration.isPressed)
    }
}

struct CustomButton: View {
    let title: String
    let action: () -> Void
    var foregroundColor: Color
    var backgroundColor: Color
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.medium)
                .background(backgroundColor)
                .foregroundColor(foregroundColor)
        }
        .buttonStyle(BaseButtonStyle(foregroundColor: foregroundColor, backgroundColor: backgroundColor))
    }
}

struct ZLHNOptionsButton: View {
    var body: some View {
        Button(action: {
            // Show the options menu when the button is tapped
        }) {
            Image(systemName: "ellipsis")
                .imageScale(.large)
        }
    }
}

struct ZLHNSectionView<Label: View>: View {
    var title: String
    var subtitle: String?
    var description: String?
    var actionTitle: String
    var foregroundColor: Color
    var backgroundColor: Color
    let label: () -> Label
    
    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                if let subtitle = subtitle {
                    Text(subtitle)
                }
                if let description = self.description {
                    Text(description)
                        .frame(maxWidth: .infinity)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    EmptyView()
                }
                label()
                Spacer()
                Divider()
            }
            .padding(.horizontal)
            .padding()
        }
        .background(Color.white)
    }
}

struct ZLHNDescriptionButton: View {
    let iconName: String
    let title: String
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .font(.title)
                .foregroundColor(.tmiPrimary)
                .frame(width: 44, height: 44)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading) {
                Text(title)
                Text(description)
                    .foregroundStyle(.black)
            }
            Spacer()
        }
        .padding(.vertical)
        .padding(.horizontal, 15)
        .background(Color.tmiBackground)
        .cornerRadius(10)
        .shadow(color: Color.gray.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct ZLHNTabNavigationButton<Tab: Equatable>: View {
    let label: String?
    let systemImage: String
    @Binding var selectedTab: Tab
    let tab: Tab
    let id: String
    
    var selectedColor: Color = .tmiPrimary
    var unselectedColor: Color = .gray
    var padding: CGFloat = 10
    var cornerRadius: CGFloat = 10
    var backgroundColor: Color = .clear
    
    var body: some View {
        Button(action: {
            self.selectedTab = self.tab
        }) {
            HStack {
                Image(systemName: systemImage)
                if let label = label {
                    Text(label)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .foregroundStyle(selectedTab == tab ? selectedColor : unselectedColor)
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
        }
        .id(id)
    }
}

struct ZLHNNavigationButton: View {
    let label: String?
    var image: String?
    var systemImage: String?
    var socialPlatform: String?
    var foregroundColor: Color = .tmiPrimary
    var labelColor: Color = .black
    var backgroundColor: Color = .clear
    var padding: CGFloat = 10
    var cornerRadius: CGFloat = 10
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                if let systemImage = self.systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(foregroundColor)
                }
                
                if let socialPlatform = self.socialPlatform {
                    Image((socialPlatform) + "-Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                }
                
                if let image = self.image {
                    Image(image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                }
                
                if let label = label {
                    Text(label)
                        .foregroundStyle(labelColor)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
        }
    }
}

struct ZLHNSocialNavigationButton: View {
    let label: String?
    let image: String
    var foregroundColor: Color = .tmiPrimary
    var labelColor: Color = .black
    var backgroundColor: Color = .clear
    var padding: CGFloat = 10
    var cornerRadius: CGFloat = 10
    var action: () -> Void
    
    var body: some View {
        Button(action: {
            action()
        }) {
            HStack {
                Image(image)
                    .foregroundStyle(foregroundColor)
                if let label = label {
                    Text(label)
                        .foregroundStyle(labelColor)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
        }
    }
}

struct JoinCampButton: View {
    @Binding var isJoined: Bool
    var action: () -> Void
    
    var body: some View {
        CustomButton(
            title: isJoined ? "Joined" : "Join",
            action: action,
            foregroundColor: .white,
            backgroundColor: isJoined ? .green : .blue
        )
    }
}

struct ApplyButton: View {
    @Binding var isApplied: Bool
    var action: () -> Void
    
    var body: some View {
        CustomButton(
            title: isApplied ? "Applied" : "Apply",
            action: action,
            foregroundColor: .white,
            backgroundColor: isApplied ? .green : .blue
        )
    }
}

#Preview {
    ButtonFactoryView()
}
