# Foundation Models API Quick Reference

## Core API Usage (iOS 26.0+)

### 1. Initialize Session

```swift
import FoundationModels

let session = try await LanguageModelSession()
```

### 2. Configure Options

```swift
let options = GenerationOptions(
    maximumResponseTokens: 1024,  // Max tokens in response
    temperature: 0.7               // Randomness (0.0-1.0)
)
```

**Available Parameters:**
- `maximumResponseTokens: Int` - Maximum number of tokens to generate
- `temperature: Double` - Controls randomness (0.0 = deterministic, 1.0 = creative)

### 3. Generate Response

```swift
let response = try await session.response(for: prompt, options: options)

// Collect streaming chunks
var fullContent = ""
for try await chunk in response {
    fullContent += chunk  // Each chunk is a String
}
```

**Response Type:**
- Returns: `AsyncThrowingStream<String, Error>`
- Each chunk is a `String` (not an enum)
- Concatenate chunks to get full response

## Guided Generation with @Generable Macro (Recommended)

For generating Swift data structures directly:

```swift
import FoundationModels

@Generable
struct ResourceData {
    let title: String
    let description: String
    let category: String
    let url: String
}

// Generate structured data - returns Response<ResourceData>
let response = try await LanguageModelSession().respond(
    to: prompt,
    generating: ResourceData.self
)

// Access the generated content
let resource = response.content
```

**Benefits:**
- Type-safe output
- No manual parsing
- Validates structure automatically
- Uses compile-time schema generation

**Important:** All nested types must also be marked with `@Generable`

**Implementation in ResourceGenerationService:**

```swift
// Define the structure with @Generable macro
// IMPORTANT: Nested types also need @Generable
@Generable
struct GeneratedResourceData {
    @Generable
    struct ResourceItem {
        let title: String
        let type: String
        let url: String
        let description: String
        let tags: [String]
    }

    let resources: [ResourceItem]
}

// Generate using respond(to:generating:) - returns Response<GeneratedResourceData>
let response = try await session.respond(
    to: prompt,
    generating: GeneratedResourceData.self
)

// Access the generated content from the response
let data = response.content

// Convert to Resource objects
let resources = data.resources.map { item in
    Resource(
        title: item.title,
        description: item.description,
        category: mapCategory(item.type),
        url: item.url,
        tags: item.tags,
        // ... other fields
    )
}
```

## Error Handling

```swift
do {
    let session = try await LanguageModelSession()
    let response = try await session.response(for: prompt, options: options)

    var content = ""
    for try await chunk in response {
        content += chunk
    }

    return content
} catch {
    // Foundation Models not available or generation failed
    print("Generation error: \(error)")
    return nil
}
```

## Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| Session creation fails | Foundation Models not available | Use `checkAvailability()` first |
| Response timeout | Prompt too complex | Reduce prompt length or tokens |
| Stream interruption | Device resource constraints | Handle partial responses |

## Best Practices

### 1. Reuse Sessions

✅ **Good:**
```swift
actor ResourceService {
    private var session: LanguageModelSession?

    func generate() async throws {
        if session == nil {
            session = try await LanguageModelSession()
        }
        // Use session
    }
}
```

❌ **Bad:**
```swift
func generate() async throws {
    let session = try await LanguageModelSession()  // Creates new session every time
    // ...
}
```

### 2. Set Appropriate Token Limits

```swift
// Short responses (titles, labels)
let options = GenerationOptions(maximumResponseTokens: 100)

// Medium responses (descriptions, summaries)
let options = GenerationOptions(maximumResponseTokens: 512)

// Long responses (articles, detailed content)
let options = GenerationOptions(maximumResponseTokens: 2048)
```

### 3. Temperature Selection

```swift
// Deterministic (factual content, data extraction)
let options = GenerationOptions(temperature: 0.0)

// Balanced (general use, educational content)
let options = GenerationOptions(temperature: 0.7)

// Creative (story writing, brainstorming)
let options = GenerationOptions(temperature: 0.9)
```

### 4. Handle Streaming Efficiently

```swift
// Buffer chunks to reduce UI updates
var buffer = ""
var lastUIUpdate = Date()

for try await chunk in response {
    buffer += chunk

    // Update UI every 0.1 seconds
    if Date().timeIntervalSince(lastUIUpdate) > 0.1 {
        await updateUI(with: buffer)
        lastUIUpdate = Date()
    }
}

// Final update
await updateUI(with: buffer)
```

## Resource Management

### Context Window Limits

According to [TN3193](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window):

- Foundation Models have limited context windows
- Typical limit: ~2048 tokens (prompt + response)
- Monitor token usage to avoid truncation

**Token Estimation:**
- ~1 token per 4 characters of English text
- "Hello world" ≈ 3 tokens
- 500 words ≈ 375 tokens

### Memory Management

```swift
actor ResourceService {
    private var session: LanguageModelSession?

    func clearSession() {
        session = nil  // Allow session to be deallocated
    }

    deinit {
        session = nil
    }
}
```

## Testing

### Check Availability

```swift
func checkFoundationModelsAvailable() async -> Bool {
    if #available(iOS 26.0, *) {
        do {
            let _ = try await LanguageModelSession()
            return true
        } catch {
            return false
        }
    }
    return false
}
```

### Device Requirements

✅ **Supported:**
- Physical devices with iOS 26.0+
- Devices with sufficient RAM and storage
- Devices with Neural Engine

❌ **Not Supported:**
- iOS Simulators (will fail)
- Devices with iOS < 26.0
- Some older devices (check availability at runtime)

## Example: Complete Implementation

```swift
import FoundationModels

@available(iOS 26.0, *)
actor AIService {
    private var session: LanguageModelSession?

    func generateText(prompt: String) async throws -> String {
        // Initialize session if needed
        if session == nil {
            session = try await LanguageModelSession()
        }

        guard let session = session else {
            throw AIError.sessionUnavailable
        }

        // Configure options
        let options = GenerationOptions(
            maximumResponseTokens: 1024,
            temperature: 0.7
        )

        // Generate response
        let response = try await session.response(for: prompt, options: options)

        // Collect chunks
        var result = ""
        for try await chunk in response {
            result += chunk
        }

        return result
    }
}

enum AIError: Error {
    case sessionUnavailable
}
```

## References

- [FoundationModels Framework](https://developer.apple.com/documentation/foundationmodels)
- [LanguageModelSession](https://developer.apple.com/documentation/FoundationModels/LanguageModelSession)
- [Generable Macro](https://developer.apple.com/documentation/foundationmodels/generable)
- [Generating Swift Data Structures with Guided Generation](https://developer.apple.com/documentation/foundationmodels/generating-swift-data-structures-with-guided-generation)
- [GenerationOptions](https://developer.apple.com/documentation/FoundationModels/GenerationOptions)
- [TN3193: Context Window Management](https://developer.apple.com/documentation/technotes/tn3193-managing-the-on-device-foundation-model-s-context-window)

---

**Last Updated:** January 2025
**iOS Version:** 26.0+
**Framework:** FoundationModels
