//import SwiftCompilerPlugin
//import SwiftSyntax
//import SwiftSyntaxBuilder
//import SwiftSyntaxMacros
//
//public struct FirestoreModelMacro: MemberMacro, ExtensionMacro {
//    public static func expansion(
//        of node: AttributeSyntax,
//        providingMembersOf declaration: some DeclGroupSyntax,
//        in context: some MacroExpansionContext
//    ) throws -> [DeclSyntax] {
//        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
//            throw FirestoreModelMacroError.notAppliedToStruct
//        }
//        
//        let properties = structDecl.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }
//        let propertyNames = properties.compactMap { $0.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text }
//        
//        let codingKeys = generateCodingKeys(propertyNames: propertyNames)
//        let initMethod = generateInitMethod(properties: properties)
//        let idProperty = generateIdProperty()
//        let dataProperty = generateDataProperty()
//        let collectionNameProperty = generateCollectionNameProperty(structName: structDecl.name.text)
//        let initFromDataMethod = generateInitFromDataMethod(properties: properties)
//        let updateMethod = generateUpdateMethod(properties: properties)
//        
//        return [codingKeys, initMethod, idProperty, dataProperty, collectionNameProperty, initFromDataMethod, updateMethod]
//    }
//    
//    public static func expansion(
//        of node: AttributeSyntax,
//        attachedTo declaration: some DeclGroupSyntax,
//        providingExtensionsOf type: some TypeSyntaxProtocol,
//        conformingTo protocols: [TypeSyntax],
//        in context: some MacroExpansionContext
//    ) throws -> [ExtensionDeclSyntax] {
//        let firestorePersistentModelExtension = try ExtensionDeclSyntax("extension \(type.trimmed): FirestorePersistentModel {}")
//        return [firestorePersistentModelExtension]
//    }
//    
//    private static func generateCodingKeys(propertyNames: [String]) -> DeclSyntax {
//        let cases = propertyNames.map { "case \($0)" }.joined(separator: "\n        ")
//        return DeclSyntax(
//               """
//               enum CodingKeys: String, CodingKey {
//                   \(raw: cases)
//               }
//               """
//        )
//    }
//    
//    private static func generateInitFromDataMethod() -> DeclSyntax {
//        return """
//            public init(id: String, data: [String: Any]) {
//                self.id = id
//                self.data = data
//            }
//            """
//    }
//    
//    private static func generateInitFromDataMethod(properties: [VariableDeclSyntax]) -> DeclSyntax {
//        let assignments = properties.map { property in
//            let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
//            let type = property.bindings.first!.typeAnnotation!.type
//            return "self.\(name) = data[\"\(name)\"] as? \(type) ?? \(type).init()"
//        }.joined(separator: "\n        ")
//        
//        return """
//               public init(id: String, data: [String: Any]) {
//                   self.id = id
//                   \(raw: assignments)
//               }
//               """
//    }
//    
//    private static func generateUpdateMethod(properties: [VariableDeclSyntax]) -> DeclSyntax {
//        let updates = properties.map { property in
//            let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
//            let type = property.bindings.first!.typeAnnotation!.type
//            return "if let value = data[\"\(name)\"] as? \(type) { self.\(name) = value }"
//        }.joined(separator: "\n        ")
//        
//        return """
//               public mutating func update(with data: [String: Any]) {
//                   \(raw: updates)
//               }
//               """
//    }
//    
//    private static func generateInitMethod(properties: [VariableDeclSyntax]) -> DeclSyntax {
//        let parameters = properties.map { property in
//            let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
//            let type = property.bindings.first!.typeAnnotation!.type
//            return "\(name): \(type)"
//        }.joined(separator: ", ")
//        
//        let assignments = properties.map { property in
//            let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
//            return "self.\(name) = \(name)"
//        }.joined(separator: "\n        ")
//        
//        return DeclSyntax(
//               """
//               init(\(raw: parameters)) {
//                   \(raw: assignments)
//               }
//               """
//        )
//    }
//    
//    private static func generateEncodeMethod(propertyNames: [String]) -> DeclSyntax {
//        let encodings = propertyNames.map { "try container.encode(\($0), forKey: .\($0))" }.joined(separator: "\n        ")
//        return DeclSyntax(
//               """
//               func encode(to encoder: Encoder) throws {
//                   var container = encoder.container(keyedBy: CodingKeys.self)
//                   \(raw: encodings)
//               }
//               """
//        )
//    }
//    
//    private static func generateDecodeMethod(properties: [VariableDeclSyntax]) -> DeclSyntax {
//        let decodings = properties.map { property in
//            let name = property.bindings.first!.pattern.as(IdentifierPatternSyntax.self)!.identifier.text
//            return "self.\(name) = try container.decode(\(property.bindings.first!.typeAnnotation!.type).self, forKey: .\(name))"
//        }.joined(separator: "\n        ")
//        
//        return DeclSyntax(
//               """
//               init(from decoder: Decoder) throws {
//                   let container = try decoder.container(keyedBy: CodingKeys.self)
//                   \(raw: decodings)
//               }
//               """
//        )
//    }
//    
//    private static func generateIdProperty() -> DeclSyntax {
//        return "public var id: String = UUID().uuidString"
//    }
//    
//    private static func generateFirestoreContextProperty() -> DeclSyntax {
//        return "var firestoreContext: FirestoreContext?"
//    }
//
//    private static func generateDataProperty() -> DeclSyntax {
//        return """
//                public var data: [String: Any] {
//                    let mirror = Mirror(reflecting: self)
//                    var dict: [String: Any] = [:]
//                    for child in mirror.children {
//                        if let label = child.label {
//                            dict[label] = child.value
//                        }
//                    }
//                    return dict
//                }
//                """
//    }
//    
//    private static func generateCollectionNameProperty(structName: String) -> DeclSyntax {
//        return "static let collectionName: String = \"\(raw: structName.lowercased())s\""
//    }
//}
//
//enum FirestoreModelMacroError: Error, CustomStringConvertible {
//    case notAppliedToStruct
//    
//    var description: String {
//        switch self {
//        case .notAppliedToStruct:
//            return "@FirestoreModel can only be applied to structs"
//        }
//    }
//}
