//
//  ImageSource.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import SwiftUI
import Combine
import FirebaseStorage


/// Represents an image that can come from either a URL or a direct UIImage
/// Used for flexible image handling throughout the app
nonisolated public enum ImageSource: Codable, Identifiable {
    /// Remote image referenced by URL string
    case url(String)
    
    /// Local image stored in memory
    case image(UIImage)
    
    // MARK: - Properties
    
    /// Unique identifier for the image source
    public var id: String {
        switch self {
        case .url(let urlString):
            return "url_\(urlString)"
        case .image(let image):
            return "image_\(image.imageFingerprint.base64EncodedString())"
        }
    }
    
    /// The URL of the image, if available
    public var url: URL? {
        switch self {
        case .url(let urlString):
            return URL(string: urlString)
        case .image:
            return nil
        }
    }
    
    /// The URL string of the image, if available
    public var urlString: String? {
        switch self {
        case .url(let urlString):
            return urlString
        case .image:
            return nil
        }
    }
    
    /// Returns the image width if available
    public var width: Int? {
        switch self {
        case .url:
            return nil // Can't determine without loading
        case .image(let image):
            return Int(image.size.width * image.scale)
        }
    }
    
    /// Returns the image height if available
    public var height: Int? {
        switch self {
        case .url:
            return nil // Can't determine without loading
        case .image(let image):
            return Int(image.size.height * image.scale)
        }
    }
    
    /// Returns the preview URL for thumbnails when available
    public var previewUrl: URL? {
        switch self {
        case .url(let urlString):
            return URL(string: urlString)
        case .image:
            return nil
        }
    }
    
    /// Returns a blurhash if available
    public var blurhash: String? {
        // In a full implementation, this might calculate or retrieve a stored blurhash
        return nil
    }
    
    /// Returns true if this is a remote URL
    public var isRemote: Bool {
        if case .url = self {
            return true
        }
        return false
    }
    
    /// Returns true if this is a local image
    public var isLocal: Bool {
        if case .image = self {
            return true
        }
        return false
    }
    
    // MARK: - Initializers
    
    /// Create from a URL string
    public init(urlString: String) {
        self = .url(urlString)
    }
    
    /// Create from a URL
    public init(url: URL) {
        self = .url(url.absoluteString)
    }
    
    /// Create from a UIImage
    public init(image: UIImage) {
        self = .image(image)
    }
    
    /// Create from image data
    public init?(data: Data) {
        guard let image = UIImage(data: data) else {
            return nil
        }
        self = .image(image)
    }
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case url
        case imageData
        case width
        case height
        case blurhash
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .url(let urlString):
            try container.encode(urlString, forKey: .url)
            
        case .image(let image):
            // For network transmission, use JPEG with moderate compression
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                throw ImageSourceError.encodingFailed
            }
            
            try container.encode(imageData, forKey: .imageData)
            
            // Store dimensions for faster access later
            let width = Int(image.size.width * image.scale)
            let height = Int(image.size.height * image.scale)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // First try URL case
        if let urlString = try? container.decode(String.self, forKey: .url) {
            self = .url(urlString)
            return
        }
        
        // Then try image data case
        if let imageData = try? container.decode(Data.self, forKey: .imageData),
           let image = UIImage(data: imageData) {
            self = .image(image)
            return
        }
        
        throw ImageSourceError.decodingFailed
    }
    
    // MARK: - Conversion Methods
    
    /// Converts the image source to Data with specified compression
    /// - Parameter quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: The image data or nil if conversion failed
    public func asData(quality: CGFloat = 0.8) throws -> Data {
        switch self {
        case .url(let urlString):
            guard let url = URL(string: urlString) else {
                throw ImageSourceError.invalidURL
            }
            
            do {
                return try Data(contentsOf: url)
            } catch {
                throw ImageSourceError.networkError(error)
            }
            
        case .image(let image):
            // Use JPEG for photos, PNG for screenshots or UI elements
            if image.hasAlphaChannel {
                guard let data = image.pngData() else {
                    throw ImageSourceError.compressionFailed
                }
                return data
            } else {
                guard let data = image.jpegData(compressionQuality: quality) else {
                    throw ImageSourceError.compressionFailed
                }
                return data
            }
        }
    }
    
  
    /// Resizes the image to target dimensions while maintaining aspect ratio
    @MainActor
    public func resized(toWidth targetWidth: CGFloat) -> ImageSource {
        switch self {
        case .url:
            // Can't resize remote images without downloading
            return self
            
        case .image(let originalImage):
            guard let resizedImage = originalImage.tmiResized(toWidth: targetWidth) else {
                return self
            }
            return .image(resizedImage)
        }
    }
}

nonisolated extension ImageSource: Equatable {
    public static func == (lhs: ImageSource, rhs: ImageSource) -> Bool {
        switch (lhs, rhs) {
        case let (.url(lhsURL), .url(rhsURL)):
            return lhsURL == rhsURL
        case let (.image(lhsImage), .image(rhsImage)):
            return lhsImage.imageFingerprint == rhsImage.imageFingerprint
        default:
            return false
        }
    }
}

nonisolated extension ImageSource: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .url(let urlString):
            hasher.combine(0)
            hasher.combine(urlString)
        case .image(let image):
            hasher.combine(1)
            hasher.combine(image.imageFingerprint)
        }
    }
}

// MARK: - Utility Functions

/// Converts an array of ImageSource to image data with error handling
/// - Parameters:
///   - images: Array of ImageSource to convert
///   - quality: JPEG compression quality (0.0 to 1.0)
/// - Returns: Array of successfully converted Data objects
/// - Throws: ImageSourceError if conversion fails
public func convertImagesToData(images: [ImageSource], quality: CGFloat = 0.8) async throws -> [Data] {
    var result: [Data] = []
    var errors: [Error] = []
    
    for imageSource in images {
        do {
            let data = try imageSource.asData(quality: quality)
            result.append(data)
        } catch {
            errors.append(error)
        }
    }
    
    // If no successful conversions but we have errors, throw the first error
    if result.isEmpty && !errors.isEmpty {
        throw errors[0]
    }
    
    return result
}

// MARK: - Firebase Storage Extensions

extension ImageSource {
    /// Error types specific to image upload operations
    public enum UploadError: Error {
        case invalidImage
        case uploadFailed(Error)
        case urlRetrievalFailed
    }
    
    /// Upload the image to Firebase Storage in the specified path
    /// - Parameters:
    ///   - storagePath: The path inside Firebase Storage where the image should be saved
    ///   - metadata: Optional metadata for the upload
    ///   - quality: JPEG compression quality for the upload (0.0 to 1.0)
    /// - Returns: The download URL of the uploaded image
    public func uploadToFirebaseStorage(
        storagePath: String,
        metadata: [String: String]? = nil,
        quality: CGFloat = 0.7
    ) async throws -> URL {
        // For remote URLs, we're already done - just return the existing URL
        if case .url(let urlString) = self, let url = URL(string: urlString) {
            return url
        }
        
        // For local images, we need to upload them
        if case .image(let image) = self {
            // Convert image to data
            let imageData: Data
            if image.hasAlphaChannel {
                guard let data = image.pngData() else {
                    throw UploadError.invalidImage
                }
                imageData = data
            } else {
                guard let data = image.jpegData(compressionQuality: quality) else {
                    throw UploadError.invalidImage
                }
                imageData = data
            }
            
            // Create a unique filename using UUID
            let filename = "\(UUID().uuidString).\(image.hasAlphaChannel ? "png" : "jpg")"
            let fullPath = "\(storagePath)/\(filename)"
            
            // Upload the image
            do {
                return try await Self.uploadImageData(
                    imageData,
                    to: fullPath,
                    metadata: metadata
                )
            } catch {
                throw UploadError.uploadFailed(error)
            }
        }
        
        throw UploadError.invalidImage
    }

    private nonisolated static func uploadImageData(
        _ data: Data,
        to path: String,
        metadata: [String: String]?
    ) async throws -> URL {
        let storageMetadata = metadata.map { values in
            let result = StorageMetadata()
            result.customMetadata = values
            return result
        }

        _ = try await Storage.storage()
            .reference()
            .child(path)
            .putDataAsync(data, metadata: storageMetadata)

        return try await Storage.storage()
            .reference()
            .child(path)
            .downloadURL()
    }
    
    /// Upload an image to Firebase Storage as a profile image
    /// - Parameters:
    ///   - userId: The user ID to associate with the profile image
    ///   - quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: The download URL of the uploaded image
    public func uploadAsProfileImage(userId: String, quality: CGFloat = 0.7) async throws -> URL {
        let path = "\(FirestoreConstants.profileImages)/\(userId)"
        return try await uploadToFirebaseStorage(storagePath: path, quality: quality)
    }
    
    /// Upload an image to Firebase Storage for a content post
    /// - Parameters:
    ///   - contentId: The content ID to associate with the image
    ///   - quality: JPEG compression quality (0.0 to 1.0)
    /// - Returns: The download URL of the uploaded image
    public func uploadAsContentImage(contentId: String, quality: CGFloat = 0.7) async throws -> URL {
        let path = "\(FirestoreConstants.contentImages)/\(contentId)"
        return try await uploadToFirebaseStorage(storagePath: path, quality: quality)
    }
}

// MARK: - UIImage Extensions

#if canImport(UIKit)
extension UIImage {
    /// Checks if the image has an alpha channel (transparency)
    nonisolated var hasAlphaChannel: Bool {
        guard let cgImage = self.cgImage else { return false }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo == .first ||
               alphaInfo == .last ||
               alphaInfo == .premultipliedFirst ||
               alphaInfo == .premultipliedLast
    }

    nonisolated var imageFingerprint: Data {
        pngData() ?? jpegData(compressionQuality: 1.0) ?? Data()
    }

    func tmiResized(toWidth targetWidth: CGFloat) -> UIImage? {
        let aspectRatio = size.width / size.height
        let targetHeight = targetWidth / aspectRatio

        UIGraphicsBeginImageContextWithOptions(CGSize(width: targetWidth, height: targetHeight), false, 0)
        draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return resizedImage
    }
}
#elseif canImport(AppKit)
import AppKit

extension UIImage {
    /// Checks if the image has an alpha channel (transparency)
    nonisolated var hasAlphaChannel: Bool {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo == .first ||
               alphaInfo == .last ||
               alphaInfo == .premultipliedFirst ||
               alphaInfo == .premultipliedLast
    }

    nonisolated var imageFingerprint: Data {
        pngData() ?? tiffRepresentation ?? Data()
    }

    nonisolated func pngData() -> Data? {
        guard let tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return imageRep.representation(using: .png, properties: [:])
    }

    nonisolated func jpegData(compressionQuality: CGFloat) -> Data? {
        guard let tiffRepresentation,
              let imageRep = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return imageRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: compressionQuality]
        )
    }

    func tmiResized(toWidth targetWidth: CGFloat) -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }

        let aspectRatio = size.width / size.height
        let targetSize = CGSize(width: targetWidth, height: targetWidth / aspectRatio)
        let resizedImage = NSImage(size: targetSize)

        resizedImage.lockFocus()
        draw(
            in: CGRect(origin: .zero, size: targetSize),
            from: CGRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1
        )
        resizedImage.unlockFocus()

        return resizedImage
    }
}
#endif
