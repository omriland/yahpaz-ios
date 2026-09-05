import Foundation
import YahpazDomain

struct EventTreatedPlateRow: Decodable, Sendable {
    var plateNumber: String?
    var model: String?
    var color: String?
    var leftWhere: String?
    var manufacturer: String?
    var logoSlug: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
        case color
        case leftWhere = "left_where"
        case manufacturer
        case logoSlug = "logo_slug"
        case sortOrder = "sort_order"
    }

    var asInput: TreatedPlateRowInput {
        TreatedPlateRowInput(
            plateNumber: plateNumber,
            model: model,
            color: color,
            leftWhere: leftWhere,
            manufacturer: manufacturer,
            logoSlug: logoSlug,
            sortOrder: sortOrder
        )
    }
}

struct TreatedPlateWrite: Encodable, Sendable {
    var eventResponderId: String
    var plateNumber: String
    var model: String?
    var color: String?
    var leftWhere: String?
    var manufacturer: String?
    var logoSlug: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case eventResponderId = "event_responder_id"
        case plateNumber = "plate_number"
        case model
        case color
        case leftWhere = "left_where"
        case manufacturer
        case logoSlug = "logo_slug"
        case sortOrder = "sort_order"
    }
}
