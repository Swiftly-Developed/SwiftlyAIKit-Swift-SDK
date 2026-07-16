import Testing
import Foundation
@testable import SwiftlyAIKit

/// Tests for the neutral tool schema's expressiveness (nested objects, arrays of objects)
/// and its JSON Schema serialization.
@Suite("AITool Schema Expressiveness Tests")
struct AIToolSchemaTests {
    private func nestedTool() -> AITool {
        AITool(
            name: "create_order",
            description: "Create an order",
            parameters: AIToolParameters(
                properties: [
                    "customer": AIToolProperty(
                        type: "object",
                        description: "Customer",
                        properties: [
                            "name": AIToolProperty(type: "string"),
                            "tier": AIToolProperty(type: "string", enumValues: ["free", "pro"])
                        ],
                        required: ["name"]
                    ),
                    "items": AIToolProperty(
                        type: "array",
                        items: AIToolPropertyItems(
                            type: "object",
                            properties: [
                                "sku": AIToolProperty(type: "string"),
                                "qty": AIToolProperty(type: "integer", minimum: 1)
                            ],
                            required: ["sku", "qty"]
                        )
                    )
                ],
                required: ["customer", "items"]
            )
        )
    }

    @Test("Nested object and array-of-object properties round-trip through Codable")
    func testCodableRoundTrip() throws {
        let tool = nestedTool()
        let data = try JSONEncoder().encode(tool)
        let decoded = try JSONDecoder().decode(AITool.self, from: data)

        let customer = decoded.parameters.properties["customer"]
        #expect(customer?.properties?["name"]?.type == "string")
        #expect(customer?.properties?["tier"]?.enum == ["free", "pro"])
        #expect(customer?.required == ["name"])

        let items = decoded.parameters.properties["items"]
        #expect(items?.items?.properties?["sku"]?.type == "string")
        #expect(items?.items?.properties?["qty"]?.minimum == 1)
        #expect(items?.items?.required == ["sku", "qty"])
    }

    @Test("jsonSchemaDictionary emits nested structure")
    func testJSONSchemaDictionary() {
        let dict = nestedTool().parameters.jsonSchemaDictionary()

        #expect(dict["type"] as? String == "object")
        let properties = dict["properties"] as? [String: Any]
        let customer = properties?["customer"] as? [String: Any]
        let customerProps = customer?["properties"] as? [String: Any]
        #expect(customerProps?["name"] != nil)

        let items = properties?["items"] as? [String: Any]
        let itemsSchema = items?["items"] as? [String: Any]
        let itemsProps = itemsSchema?["properties"] as? [String: Any]
        #expect(itemsProps?["sku"] != nil)
        #expect(itemsProps?["qty"] != nil)
    }

    @Test("jsonSchemaDictionary is JSON-serializable")
    func testDictionarySerializable() throws {
        let dict = nestedTool().parameters.jsonSchemaDictionary()
        #expect(JSONSerialization.isValidJSONObject(dict))
        let data = try JSONSerialization.data(withJSONObject: dict)
        #expect(!data.isEmpty)
    }
}
