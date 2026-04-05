import SwiftUI

struct AccordionSection<Content: View>: View {
    let icon: String
    let title: String
    var badge: String? = nil
    var badgeColor: Color = .blue
    var isRequired: Bool = false
    var accentColor: Color? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    if isRequired {
                        Text("REQUIRED")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.tmiTextPrimary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red, in: RoundedRectangle(cornerRadius: 4))
                    }

                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Color.tmiTextPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(badgeColor, in: Capsule())
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    accentColor != nil ? Color.tmiSurfaceTinted : Color.clear
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                content()
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .leading) {
            if let accentColor {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
