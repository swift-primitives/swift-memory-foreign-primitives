// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-primitives open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-primitives project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Memory_Primitive
public import Memory_Address_Primitives
public import Memory_Region_Primitives
public import Span_Raw_Primitives

// MARK: - Region (element-free raw-region seam)

/// The conformance IS the tower integration: a `Memory.Region` allocation flows through
/// `Storage.Contiguous`'s existing convenience initializer with zero storage-tier
/// changes; release semantics stay encapsulated in this regime's own `deinit`, which the
/// storage drop cascade never names.
extension Memory.Foreign: Memory.Region {
    /// The stable base address of the region's first byte.
    @inlinable
    public var base: Memory.Address {
        // SAFETY: `nonNull` yields a non-null start, and the adopting initializer's
        // SAFETY: non-empty precondition excludes the sentinel; the address is valid for
        // SAFETY: this value's lifetime by the adoption contract. The integer-address
        // SAFETY: model carries no provenance. [MEM-SAFE-025a]
        unsafe Memory.Address(_region.base.nonNull.baseAddress!)
    }

    /// The region's capacity in bytes.
    @inlinable
    public var capacity: Memory.Address.Count {
        Memory.Address.Count(UInt(unsafe _region.base.nonNull.count))
    }
}
