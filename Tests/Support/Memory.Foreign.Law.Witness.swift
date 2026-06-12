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

extension Memory.Foreign.Law {
    /// Counts finalizer invocations so the exactly-once law is checkable from outside,
    /// including from finalizers that run in another isolation domain (the value is
    /// non-Sendable and crosses as `consuming sending`; the witness must not be).
    public final class Witness: Sendable {
        private let _invocations = Atomic<Int>(0)

        public init() {}

        /// The number of finalizer invocations recorded so far.
        public var invocations: Int {
            _invocations.load(ordering: .sequentiallyConsistent)
        }

        /// Records one finalizer invocation.
        public func record() {
            _invocations.wrappingAdd(1, ordering: .relaxed)
        }
    }
}
