//
//  FirestoreConstants.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase
@preconcurrency import FirebaseAuth
@preconcurrency import FirebaseFirestore
@preconcurrency import FirebaseStorage

struct FirestoreConstants {
    // Authentication
    static var currentUser: User? { Auth.auth().currentUser }
    static let uid = "uid"

    // User Fields
    static let users = "users"
    static let name = "name"
    static let username = "username"
    static let email = "email"
    static let bio = "bio"
    static let profileImageUrl = "profileImageUrl"
    static let userStatus = "status"
    static let userType = "userType"
    static let followingCampIDs = "followingCampIDs"

    // Chat Fields
    static let chats = "chats"
    static let messages = "messages"
    static let chatParticipants = "chatParticipants"
    static let chatName = "chatName"
    static let chatImageUrl = "chatImageUrl"
    static let lastMessage = "lastMessage"
    static let lastMessageTime = "lastMessageTime"
    static let seenBy = "seenBy"

    // Post Fields
    static let content = "content"
    static let timestamp = "timestamp"
    static let contentComments = "content_comments"
    static let createdAt = "createdAt"

    // Storage Paths
    static let profileImages = "profile_images"
    static let chatImages = "chat_images"
    static let messageImages = "message_images"
    static let contentImages = "content_images"
    static let videoMessage = "video_message"
}


// MARK: - Firestore Collection References
enum FirestoreCollection: String {
    case hammocks = "hammocks"
    
    // Camp related data
    case camps = "camps"
    case campProfiles = "camp_profiles"
    case campFeed = "camp_feed"
    
    // User related data
    case users = "users"
    case students = "students"
    case staff = "staff"
    case owners = "owners"
    case alumni = "alumni"
    case guardians = "guardians"
    case guests = "guests"
    case donors = "donors"
    case campers = "campers"
    case caregivers = "caregivers"
    case organizations = "organizations"
    case admin = "admin"
    case teacher = "teacher"
    case counselor = "counselor"
    case parent = "parent"
    
    // User activity and interactions
    case userFeed = "user_feed"
    case userContent = "user_content"
    case userUpvotes = "user_upvotes"
    case userReposts = "user_reposts"
    case userMessages = "user_messages"
    case userProfiles = "user_profiles"
    case userDownvotes = "user_downvotes"
    case userFollowing = "user_following"
    case userFollowers = "user_followers"
    case userMessageNotifications = "user_message_notifications"
    
    // Content and interaction data
    case content = "content"
    case contentUpvotes = "content_upvotes"
    case contentReposts = "content_reposts"
    case contentComments = "content_comments"
    case contentDownvotes = "content_downvotes"
    case comments = "comments"
    case hashtagContent = "hashtag_content"
    
    // Communication data
    case chats = "chats"
    case messages = "messages"
    case recentChats = "recent_chats"
    case recentMessages = "recent_messages"
    
    // Scheduling and notifications
    case schedules = "schedules"
    case notifications = "notifications"
    
    // Form and template data
    case surveys = "surveys"
    case forms = "forms"
    case formTemplates = "form_templates"
    case formSubmissions = "form_submissions"
    
    // Miscellaneous feeds
    case homeFeed = "home_feed"
    
    // District Pilot
    case districts = "districts"
    case schools = "schools"
    
    case interests = "interests"
    case hobbies = "hobbies"
    case tmiPlans = "tmi_plans"
    case resources = "resources"
    
    case generatedResources = "generatedResources"
    
    func reference() -> CollectionReference {
        FirebaseManager.shared.firestore.collection(self.rawValue)
    }
}

// MARK: - Storage Constants
struct StorageConstants {
    static var storageRootRef: StorageReference {
        FirebaseManager.shared.storage.reference()
    }
    
    static var storageChatImagesRef: StorageReference {
        storageRootRef.child(FirestoreConstants.chatImages)
    }
    
    static var storageProfileImagesRef: StorageReference {
        storageRootRef.child(FirestoreConstants.profileImages)
    }
    
    static var storageMessageImagesRef: StorageReference {
        storageRootRef.child(FirestoreConstants.messageImages)
    }
    
    static var storagePostImagesRef: StorageReference {
        storageRootRef.child(FirestoreConstants.contentImages)
    }
    
    static var storageVideoMessageRef: StorageReference {
        storageRootRef.child(FirestoreConstants.videoMessage)
    }
}

struct FirestoreDecodingValues {
    static let upvoteIntValue = 0
    static let downvoteIntValue = 1
    static let commentIntValue = 2
    static let followIntValue = 3
    static let commentMentionIntValue = 4
    static let contentMentionIntValue = 5
}

// MARK: - Codable document identity

nonisolated extension DocumentSnapshot {
    /// Decodes a model and restores the canonical Firestore document ID.
    ///
    /// Models intentionally keep persistence wrappers out of their Sendable
    /// domain representation, so identity must be assigned at the repository
    /// boundary after decoding.
    func decodedModel<Value: Decodable>(
        as type: Value.Type,
        assigningDocumentIDTo keyPath: WritableKeyPath<Value, String?>
    ) throws -> Value {
        var value = try data(as: type)
        value[keyPath: keyPath] = documentID
        return value
    }
}

nonisolated extension DocumentReference {
    /// Selects Firestore's synchronous, completionless overload so the write is
    /// queued locally even when the client has no network connection.
    fileprivate func enqueueDataLocally(_ data: [String: Any], merge: Bool) {
        setData(data, merge: merge, completion: nil)
    }

    /// Encodes a model and performs an offline-capable local enqueue.
    ///
    /// Returning from this helper means Firestore accepted the write into its
    /// local queue; it does not confirm server acknowledgement. Operations that
    /// require an online acknowledgement must use a separate confirmed-write contract.
    func setModel<Value: Encodable>(
        _ value: Value,
        merge: Bool = false
    ) async throws {
        let data = try Firestore.Encoder().encode(value)
        enqueueDataLocally(data, merge: merge)
    }
}

nonisolated extension CollectionReference {
    /// Encodes a model and performs an offline-capable local enqueue.
    ///
    /// The returned identifier is allocated locally. This helper does not
    /// confirm server acknowledgement; online-required transitions need a
    /// separate confirmed-write contract.
    @discardableResult
    func addModel<Value: Encodable>(_ value: Value) async throws -> String {
        let data = try Firestore.Encoder().encode(value)
        let reference = document()
        reference.enqueueDataLocally(data, merge: false)
        return reference.documentID
    }
}
