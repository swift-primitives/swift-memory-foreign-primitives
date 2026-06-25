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

public import Memory_Foreign_Primitives

extension Memory.Foreign {
    /// Adopts a fresh heap allocation as a Foreign region whose finalizer deallocates
    /// the bytes and records on the census — the standard fixture for exactly-once and
    /// not-before-drop checks. The heap backing stands in for any provider (an io_uring
    /// provided buffer, a C-library allocation); the regime under test is the envelope,
    /// not the provenance. `alignment` is exposed so consumers exercising the non-byte
    /// half of the adoption contract (element alignment is the adopter's obligation at
    /// the storage-construction seam) can provision accordingly.
    public static func fixture(byteCount: Int, alignment: Int = 16, census: Census) -> Memory.Foreign {
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: byteCount, alignment: alignment)
        return unsafe Memory.Foreign(adopting: unsafe .init(raw)) { region in
            unsafe region.base.nullable.deallocate()
            census.record()
        }
    }
}
