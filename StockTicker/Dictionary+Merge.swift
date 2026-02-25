import Foundation

extension Dictionary {
    mutating func mergeKeepingNew(_ other: [Key: Value]) {
        merge(other) { _, new in new }
    }

    mutating func mergeKeepingExisting(_ other: [Key: Value]) {
        merge(other) { existing, _ in existing }
    }

    func mergingKeepingExisting(_ other: [Key: Value]) -> [Key: Value] {
        merging(other) { existing, _ in existing }
    }
}
