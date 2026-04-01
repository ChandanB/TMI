//
//  View+Extensions.swift
//  TMI
//
//  Created by Chandan Brown on 9/13/24.
//

import SwiftUI

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        path.addArc(
            center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
            radius: topRight,
            startAngle: .degrees(-90),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
            radius: bottomRight,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
            radius: bottomLeft,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        path.addArc(
            center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
            radius: topLeft,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        return path
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    @ViewBuilder
    func placeholder<Content: View>(when shouldShow: Bool, alignment: Alignment = .leading, @ViewBuilder content: () -> Content) -> some View {
        ZStack(alignment: alignment) {
            if shouldShow {
                content()
            }
            self
        }
    }
    
    func customFont(name: String, size: CGFloat) -> some View {
        self.modifier(CustomFontModifier(fontName: name, size: size))
    }
    
    func coordinatedOverlay<Content: View>(_ overlay: Content, alignment: Alignment = .center) -> some View {
        self.modifier(CoordinatedOverlay(overlayView: overlay, alignment: alignment))
    }

    func keyboardAvoiding() -> some View {
        ModifiedContent(content: self, modifier: KeyboardAvoiding())
    }

    func bottomSheet<Content: View>(height: CGFloat, isOpen: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        self.modifier(BottomSheet(sheetHeight: height, sheetContent: content, isOpen: isOpen))
    }
}

#if canImport(UIKit)
extension UIApplication {
    func endEditing(_ force: Bool) {
        if #available(iOS 15.0, *) {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?
                .endEditing(force)
        } else {
            self.windows
                .filter { $0.isKeyWindow }
                .first?
                .endEditing(force)
        }
    }
}
#endif

extension View {
    /// Creates a binding for any property on an object
    /// - Parameters:
    ///   - object: Observable object
    ///   - keyPath: Path to the property
    /// - Returns: A binding to the property
    func binding<Object, T>(_ object: Object, _ keyPath: ReferenceWritableKeyPath<Object, T>) -> Binding<T> {
        Binding(
            get: { object[keyPath: keyPath] },
            set: { object[keyPath: keyPath] = $0 }
        )
    }
}
