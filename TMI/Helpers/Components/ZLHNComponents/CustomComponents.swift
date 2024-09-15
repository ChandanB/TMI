//
//  CustomComponents.swift
//  CAMP APP
//
//  Created by Chandan Brown on 3/21/24.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import AVKit

struct BottomSheet<SheetContent: View>: ViewModifier {
    let sheetHeight: CGFloat
    let sheetContent: () -> SheetContent
    @Binding var isOpen: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            VStack {
                Spacer()
                VStack {
                    Handle()
                    sheetContent()
                }
                .frame(height: sheetHeight)
                .background(Color(.systemBackground))
                .shadow(color: Color(.black).opacity(0.2), radius: 5, x: 0, y: -5)
                .offset(y: isOpen ? 0 : sheetHeight)
                .gesture(DragGesture().onEnded { value in
                    if value.translation.height > 50 {
                        withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.7, blendDuration: 0)) {
                            isOpen = false
                        }
                    }
                })
            }
        }
    }
    
    struct Handle: View {
        var body: some View {
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray3))
                .frame(width: 40, height: 5)
                .padding(.top)
        }
    }
}

struct VisualEffectBlur: UIViewRepresentable {
    var blurStyle: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: blurStyle))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

// Helper view modifier to create the coordinated overlay
struct CoordinatedOverlay<OverlayView: View>: ViewModifier {
    var overlayView: OverlayView
    var alignment: Alignment
    
    func body(content: Content) -> some View {
        content
            .overlay(overlayView, alignment: alignment)
    }
}

struct KeyboardAvoiding: ViewModifier {
    @State private var keyboardHeight: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .padding(.bottom, keyboardHeight)
            .onAppear(perform: subscribeToKeyboardEvents)
            .onDisappear(perform: unsubscribeFromKeyboardEvents)
    }
    
    private func subscribeToKeyboardEvents() {
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main) { (notification) in
            guard let userInfo = notification.userInfo else { return }
            guard let keyboardEndFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            keyboardHeight = keyboardEndFrame.height
        }
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { (_) in
            keyboardHeight = 0
        }
    }
    
    private func unsubscribeFromKeyboardEvents() {
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
    }
}

struct CustomFontModifier: ViewModifier {
    let fontName: String
    let size: CGFloat
    
    func body(content: Content) -> some View {
        content.font(Font.custom(fontName, size: size))
    }
}

struct VideoPlayerView: View {
    var videoURL: URL
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url: videoURL))
            .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - ImageColors
struct ImageColors {
    var background: Color
    var primary: Color
    var secondary: Color
    var detail: Color
}

// MARK: - ColorExtractionService
class ColorExtractionService {
    func extractColors(from image: UIImage) async -> ImageColors? {
        // Actual color extraction logic
        return nil
    }
}

// MARK: - DocumentPicker
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var documentURL: URL?
    var didPickDocument: (Data) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.pdf], asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate, UINavigationControllerDelegate {
        var parent: DocumentPicker
        
        init(_ documentPicker: DocumentPicker) {
            self.parent = documentPicker
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            
            if let data = try? Data(contentsOf: url) {
                parent.didPickDocument(data)
                parent.documentURL = url
            }
        }
    }
}
