import Foundation

// MARK: - Mock Product

struct MockProduct: Codable, Sendable {
    let id: UUID
    let name: String
    let description: String
    let price: Double
    let category: String
    let quantity: Int
    let imageUrl: String?
}

// MARK: - Mock Basket Item

struct MockBasketItem: Codable, Sendable {
    let id: UUID
    let productID: UUID
    let productName: String
    let quantity: Int
    let price: Double
    let imageUrl: String?
}

// MARK: - Mock User

struct MockUser: Codable, Sendable {
    let id: UUID
    let userName: String
}

// MARK: - Factory

enum MockDataFactory {

    // MARK: - Products

    static let products: [MockProduct] = [
        MockProduct(
            id: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
            name: "MacBook Pro 16-inch M3 Max",
            description: "Apple M3 Max chip with 16-core CPU, 40-core GPU, 48GB unified memory, 1TB SSD. Space Black.",
            price: 3499.00,
            category: "Laptops",
            quantity: 15,
            imageUrl: "https://picsum.photos/id/1/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "B7B62A9E-6A3D-4F1C-9B8D-2E5F1C8A7D6E")!,
            name: "iPhone 16 Pro Max 256GB",
            description: "6.9-inch Super Retina XDR display, A18 Pro chip, 5x optical zoom, Titanium design. Natural Titanium.",
            price: 1199.00,
            category: "Phones",
            quantity: 42,
            imageUrl: "https://picsum.photos/id/20/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
            name: "AirPods Pro 2nd Generation USB-C",
            description: "Adaptive Audio, Active Noise Cancellation, Transparency mode, Personalized Spatial Audio, MagSafe USB-C.",
            price: 249.00,
            category: "Audio",
            quantity: 100,
            imageUrl: "https://picsum.photos/id/30/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "D4E5F6A7-B8C9-0123-4567-890ABCDEF123")!,
            name: "iPad Air 13-inch M2",
            description: "13-inch Liquid Retina display, M2 chip, 128GB storage, Wi-Fi 6E, Apple Pencil Pro support. Starlight.",
            price: 799.00,
            category: "Tablets",
            quantity: 28,
            imageUrl: "https://picsum.photos/id/40/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "FEDCBA98-7654-3210-FEDC-BA9876543210")!,
            name: "Apple Watch Ultra 2",
            description: "49mm titanium case, Bright 3000-nit display, Precision dual-frequency GPS, Action button, 36h battery.",
            price: 799.00,
            category: "Wearables",
            quantity: 20,
            imageUrl: "https://picsum.photos/id/50/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "Mac mini M4 Pro",
            description: "M4 Pro chip with 14-core CPU, 20-core GPU, 24GB unified memory, 512GB SSD. Compact desktop powerhouse.",
            price: 1599.00,
            category: "Desktops",
            quantity: 10,
            imageUrl: "https://picsum.photos/id/60/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "22222222-3333-4444-5555-666666666666")!,
            name: "Apple AirTag 4-Pack",
            description: "Find your items with precision finding. Replaceable CR2032 battery. IP67 water and dust resistant.",
            price: 99.00,
            category: "Accessories",
            quantity: 200,
            imageUrl: "https://picsum.photos/id/70/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "33333333-4444-5555-6666-777777777777")!,
            name: "Belkin BoostCharge Pro 3-in-1",
            description: "15W MagSafe charger for iPhone, Apple Watch Fast Charger, AirPods. Foldable design, works with StandBy mode.",
            price: 149.99,
            category: "Chargers",
            quantity: 35,
            imageUrl: "https://picsum.photos/id/80/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "44444444-5555-6666-7777-888888888888")!,
            name: "AirPods Max - Midnight Blue",
            description: "Over-ear headphones with spatial audio, active noise cancellation, transparency mode, 20h battery life.",
            price: 549.00,
            category: "Audio",
            quantity: 12,
            imageUrl: "https://picsum.photos/id/90/400/400"
        ),
        MockProduct(
            id: UUID(uuidString: "55555555-6666-7777-8888-999999999999")!,
            name: "Apple Pencil Pro",
            description: "Squeeze gesture, barrel roll, haptic feedback, Find My support. Works with M2 iPad Air and M4 iPad Pro.",
            price: 129.00,
            category: "Accessories",
            quantity: 60,
            imageUrl: "https://picsum.photos/id/100/400/400"
        )
    ]

    // MARK: - Basket Items

    static let basketItems: [MockBasketItem] = [
        MockBasketItem(
            id: UUID(),
            productID: UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
            productName: "MacBook Pro 16-inch M3 Max",
            quantity: 1,
            price: 3499.00,
            imageUrl: "https://picsum.photos/id/1/400/400"
        ),
        MockBasketItem(
            id: UUID(),
            productID: UUID(uuidString: "A1B2C3D4-E5F6-7890-ABCD-EF1234567890")!,
            productName: "AirPods Pro 2nd Generation USB-C",
            quantity: 2,
            price: 249.00,
            imageUrl: "https://picsum.photos/id/30/400/400"
        )
    ]
}
