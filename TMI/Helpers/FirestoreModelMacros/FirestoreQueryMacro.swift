////
////  File.swift
////  
////
////  Created by Chandan Brown on 9/12/24.
////
//
//import SwiftCompilerPlugin
//import SwiftSyntax
//import SwiftSyntaxBuilder
//import SwiftSyntaxMacros
//
//@main
//struct FirestoreModelPlugin: CompilerPlugin {
//    let providingMacros: [Macro.Type] = [
//        FirestoreModelMacro.self,
//        FirestoreQueryMacro.self,
//    ]
//}
//
//public struct FirestoreQueryMacro: AccessorMacro, PeerMacro {
//    public static func expansion(
//        of node: AttributeSyntax,
//        providingAccessorsOf declaration: some DeclSyntaxProtocol,
//        in context: some MacroExpansionContext
//    ) throws -> [AccessorDeclSyntax] {
//        guard let varDecl = declaration.as(VariableDeclSyntax.self),
//              let binding = varDecl.bindings.first,
//              let typeAnnotation = binding.typeAnnotation?.type,
//              let genericArgs = typeAnnotation.as(IdentifierTypeSyntax.self)?.genericArgumentClause
//        else {
//            throw FirestoreQueryMacroError.invalidDeclaration
//        }
//
//        let elementType = genericArgs.arguments.first!.argument
//
//        let getterBody = CodeBlockItemListSyntax("""
//        FirestoreQueryProvider.shared.fetch(
//            type: \(elementType).self,
//            filter: _firestoreQueryFilter,
//            limit: _firestoreQueryLimit,
//            order: _firestoreQueryOrder
//        )
//        """)
//
//        return [
//            AccessorDeclSyntax(
//                accessorSpecifier: .keyword(.get),
//                body: CodeBlockSyntax(statements: getterBody)
//            )
//        ]
//    }
//
//    public static func expansion(
//        of node: AttributeSyntax,
//        providingPeersOf declaration: some DeclSyntaxProtocol,
//        in context: some MacroExpansionContext
//    ) throws -> [DeclSyntax] {
//        let filterDecl = try VariableDeclSyntax("private var _firestoreQueryFilter: ((Query) -> Query)?")
//        let limitDecl = try VariableDeclSyntax("private var _firestoreQueryLimit: Int?")
//        let orderDecl = try VariableDeclSyntax("private var _firestoreQueryOrder: (String, Bool)?")
//
//        return [filterDecl.cast(DeclSyntax.self), limitDecl.cast(DeclSyntax.self), orderDecl.cast(DeclSyntax.self)]
//    }
//}
//
//enum FirestoreQueryMacroError: Error, CustomStringConvertible {
//    case invalidDeclaration
//
//    var description: String {
//        switch self {
//        case .invalidDeclaration:
//            return "@FirestoreQuery can only be applied to a stored property with an array type"
//        }
//    }
//}
