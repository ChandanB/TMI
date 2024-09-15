//
//  FirestoreConstants.swift
//  TMI
//
//  Created by Chandan Brown on 9/14/24.
//

import Firebase
import FirebaseFirestore
import FirebaseStorage

struct FirestoreConstants {
    // Authentication
//    static let currentUser = Auth.auth().currentUser
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
    
    case interests
    case hobbies
    case tmiPlans
    case resources
    
    func reference() -> CollectionReference {
        FirebaseManager.shared.firestore.collection(self.rawValue)
    }
}

// MARK: - Storage Constants
struct StorageConstants {
    static let storageRootRef = FirebaseManager.shared.storage.reference()
    static let storageChatImagesRef = storageRootRef.child(FirestoreConstants.chatImages)
    static let storageProfileImagesRef = storageRootRef.child(FirestoreConstants.profileImages)
    static let storageMessageImagesRef = storageRootRef.child(FirestoreConstants.messageImages)
    static let storagePostImagesRef = storageRootRef.child(FirestoreConstants.contentImages)
    static let storageVideoMessageRef = storageRootRef.child(FirestoreConstants.videoMessage)
}

struct FirestoreDecodingValues {
    static let upvoteIntValue = 0
    static let downvoteIntValue = 1
    static let commentIntValue = 2
    static let followIntValue = 3
    static let commentMentionIntValue = 4
    static let contentMentionIntValue = 5
}


