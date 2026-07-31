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
import Synchronization

extension Memory.Foreign {
    /// Counts finalizer invocations so release behavior is observable from tests
    /// (the lifecycle-census fixture shape; precedent: `Model.Census` in
    /// swift-buffer-primitives Test Support — named *Census*, not *Witness*, because
    /// `Namespace.Witness` is reserved for type-erased capability-protocol witnesses
    /// per [PKG-NAME-015]).
    ///
    /// Exactly-once release is structural (`~Copyable`: one owner, one drop, one
    /// deinit) — this census does not enforce it. It exists for the two things the
    /// type system cannot check:
    ///
    /// 1. **The guarded-deinit workaround.** `discard self` requires trivially-destroyed
    ///    stored properties, so `take()` nils the Optional finalizer and the deinit
    ///    guards on it — two lines whose correctness is an implementation invariant,
    ///    not a type-system theorem. The census pins them against regression; when
    ///    the toolchain wall falls and `take()` becomes `discard self`, those pins
    ///    can retire.
    /// 2. **The caller's half of the adoption contract.** The `@unsafe` init asserts
    ///    what the compiler cannot verify (no double-adoption, finalizer actually
    ///    releases, region valid until release). Consumers — a receive pool wiring
    ///    its recycle closure — use this census to test their side.
    ///
    /// Sendable (atomic counter) so it can observe finalizers that run in another
    /// isolation domain — the value itself is non-Sendable and crosses as
    /// `consuming sending`; its observer must not be.
    public final class Census: Sendable {
        private let _invocations = Atomic<Int>(0)

        public init() {}
    }
}

extension Memory.Foreign.Census {
    /// The number of finalizer invocations recorded so far.
    public var invocations: Int {
        _invocations.load(ordering: .sequentiallyConsistent)
    }

    /// Records one finalizer invocation.
    public func record() {
        _invocations.wrappingAdd(1, ordering: .relaxed)
    }
}
