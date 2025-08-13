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
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
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