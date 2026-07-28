import SwiftUI

/// Release 1 does not derive engagement or support status from legacy student
/// documents. The widget stays intentionally informational until the canonical
/// metrics release provides server-owned values.
struct StudentStatusWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: TMISpacing.md) {
            Label("Student status metrics", systemImage: "chart.bar.xaxis")
                .font(.tmiTitle3.bold())
                .foregroundColor(.tmiPrimary)

            Text("Available after canonical engagement metrics ship. The dashboard does not estimate or fabricate student status.")
                .font(.tmiBody)
                .foregroundColor(.tmiTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    StudentStatusWidget()
        .padding()
}
