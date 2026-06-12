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
    /// Seam laws for the `Memory.Region` conformance and the finalizer contract.
    ///
    /// The laws a `Memory.Region` conformer owes its consumers, checkable from outside:
    /// base stability and capacity constancy across the value's lifetime, and the
    /// finalizer contract — exactly once, never before drop.
    public enum Law {}
}

extension Memory.Foreign.Law {
    /// `base` is stable across repeated reads of the same live value.
    public static func baseStability(_ foreign: borrowing Memory.Foreign) -> Bool {
        foreign.base == foreign.base
    }

    /// `capacity` is constant across repeated reads of the same live value.
    public static func capacityConstancy(_ foreign: borrowing Memory.Foreign) -> Bool {
        foreign.capacity == foreign.capacity
    }

    /// Adopts a fresh heap allocation as a Foreign region whose finalizer deallocates
    /// the bytes and records on the witness — the standard fixture for exactly-once and
    /// not-before-drop checks. The heap backing stands in for any provider (an io_uring
    /// provided buffer, a C-library allocation); the regime under test is the envelope,
    /// not the provenance.
    public static func heapBacked(byteCount: Int, witness: Witness) -> Memory.Foreign {
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: byteCount, alignment: 16)
        return unsafe Memory.Foreign(adopting: unsafe Span.Raw.Mutable(raw)) { region in
            unsafe region.base.nullable.deallocate()
            witness.record()
        }
    }
}
