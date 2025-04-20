//
//  ImageSource.swift
//  TMI
//
//  Created by Chandan Brown on 4/20/25.
//

import UIKit
import Combine

/// Represents an image that can come from either a URL or a direct UIImage
/// Used for flexible image handling throughout the app
public enum ImageSource: Codable, Hashable, Identifiable, Sendable {
    /// Remote image referenced by URL string
    case url(String)
    
    /// Local image stored in memory
    case image(UIImage)
    
    // MARK: - Properties
    
    /// Unique identifier for the image source
    public var id: String {
        switch self {
        case .url(let urlString):
            return "url_\(urlString.hashValue)"
        case .image:
            return "image_\(UUID().uuidString)"
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
    public func resized(toWidth targetWidth: CGFloat) -> ImageSource {
        switch self {
        case .url:
            // Can't resize remote images without downloading
            return self
            
        case .image(let originalImage):
            let aspectRatio = originalImage.size.width / originalImage.size.height
            let targetHeight = targetWidth / aspectRatio
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: targetWidth, height: targetHeight), false, 0)
            originalImage.draw(in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let resizedImage = resizedImage {
                return .image(resizedImage)
            }
            return self
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
            let data = try await Task {
                try imageSource.asData(quality: quality)
            }.value
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

// MARK: - UIImage Extensions

extension UIImage {
    /// Checks if the image has an alpha channel (transparency)
    var hasAlphaChannel: Bool {
        guard let cgImage = self.cgImage else { return false }
        let alphaInfo = cgImage.alphaInfo
        return alphaInfo == .first ||
               alphaInfo == .last ||
               alphaInfo == .premultipliedFirst ||
               alphaInfo == .premultipliedLast
    }
}
