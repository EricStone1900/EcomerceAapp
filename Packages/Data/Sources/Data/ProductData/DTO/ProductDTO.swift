import Foundation

import ProductAbstraction

struct ProductDTO: Codable {

    var id: UUID

    var name: String

    var description: String

    var price: Double

    var category: String

    var quantity: Int

    var imageURL: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case price
        case category
        case quantity
        case imageURL = "image_url"
    }
}
