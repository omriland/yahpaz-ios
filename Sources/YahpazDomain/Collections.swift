import Foundation

/// `Dictionary(uniqueKeysWithValues:)` traps when the same id appears twice.
/// Unit + my-active + pinned event lists overlap by design; last write wins.
public func keyedLastWins<Key: Hashable, Value>(_ pairs: [(Key, Value)]) -> [Key: Value] {
    Dictionary(pairs, uniquingKeysWith: { _, last in last })
}

public func keyedLastWins<Item: Identifiable>(_ items: [Item]) -> [Item.ID: Item] where Item.ID: Hashable {
    keyedLastWins(items.map { ($0.id, $0) })
}

/// Concatenate overlapping id lists (unit + my-active + pinned) without trapping.
public func mergeIdentifiedLastWins<Item: Identifiable>(_ lists: [Item]...) -> [Item.ID: Item]
where Item.ID: Hashable {
    keyedLastWins(lists.flatMap { $0 })
}
