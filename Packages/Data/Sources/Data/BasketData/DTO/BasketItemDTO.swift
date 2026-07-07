import Foundation

struct BasketItemDTO: Codable {

    var id: UUID

    var productID: UUID

    var productName: String

    var quantity: Int

    var price: Double

    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case productID = "product_id"
        case productName = "product_name"
        case quantity
        case price
        case imageURL = "image_url"
    }
}
