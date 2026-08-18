import Foundation
import YahpazDomain

struct EventTreatedPlateRow: Decodable, Sendable {
    var plateNumber: String?
    var model: String?
    var color: String?
    var sortOrder: Int?

    enum CodingKeys: String, CodingKey {
        case plateNumber = "plate_number"
        case model
        case color
        case sortOrder = "sort_order"
    }

    var asInput: TreatedPlateRowInput {
        TreatedPlateRowInput(
            plateNumber: plateNumber,
            model: model,
            color: color,
            sortOrder: sortOrder
        )
    }
}

struct TreatedPlateWrite: Encodable, Sendable {
    var eventResponderId: String
    var plateNumber: String
    var model: String?
    var color: String?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case eventResponderId = "event_responder_id"
        case plateNumber = "plate_number"
        case model
        case color
        case sortOrder = "sort_order"
    }
}
