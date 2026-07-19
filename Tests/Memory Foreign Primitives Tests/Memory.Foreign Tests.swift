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

import Memory_Foreign_Primitives
import Memory_Foreign_Primitives_Test_Support
import Testing

// The foreign regime leaf: an owning envelope (`Span.Raw.Mutable` + finalizer +
// `~Copyable` uniqueness) over memory this process did not allocate, conforming the
// `Memory.Region` seam. These tests cover the envelope's own surface — adoption,
// exactly-once release, custody transfer, and region-isolation crossing. Storage-tier
// composition over the `Memory.Region` seam is exercised by the
// foreign-region-tower-instantiation experiment (swift-buffer-ring-primitives).

extension Memory.Foreign {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct EdgeCase {}
        @Suite struct Integration {}
    }
}

// MARK: - Unit

extension Memory.Foreign.Test.Unit {
    @Test
    func `drop runs the finalizer exactly once`() {
        let census = Memory.Foreign.Census()
        do {
            let foreign = Memory.Foreign.fixture(byteCount: 64, census: census)
            #expect(census.invocations == 0, "the finalizer must not run before drop")
            _ = foreign.capacity
        }
        #expect(census.invocations == 1)
    }

    @Test
    func `base and capacity reflect the adopted region`() {
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: 128, alignment: 16)
        let expected = unsafe Memory.Address(raw.baseAddress!)
        let foreign = unsafe Memory.Foreign(adopting: unsafe .init(raw)) { region in
            unsafe region.base.nullable.deallocate()
        }
        #expect(foreign.base == expected)
        #expect(foreign.capacity.underlying == 128)
    }

    @Test
    func `take transfers custody without invoking and the guarded deinit does not double-run`() {
        let census = Memory.Foreign.Census()
        let foreign = Memory.Foreign.fixture(byteCount: 64, census: census)
        let (region, finalizer) = foreign.take()
        #expect(census.invocations == 0, "take() must not invoke the finalizer")
        finalizer(region)
        #expect(census.invocations == 1, "manual invocation after take() releases once")
    }

    @Test
    func `taken custody can be re-adopted and releases exactly once on the second drop`() {
        let census = Memory.Foreign.Census()
        do {
            let first = Memory.Foreign.fixture(byteCount: 64, census: census)
            let (region, finalizer) = first.take()
            let second = unsafe Memory.Foreign(adopting: region, finalizer: finalizer)
            #expect(census.invocations == 0)
            _ = second.base
        }
        #expect(census.invocations == 1)
    }
}

// MARK: - Edge cases

extension Memory.Foreign.Test.EdgeCase {
    @Test
    func `single-byte region is valid`() {
        let census = Memory.Foreign.Census()
        do {
            let foreign = Memory.Foreign.fixture(byteCount: 1, census: census)
            #expect(foreign.capacity.underlying == 1)
        }
        #expect(census.invocations == 1)
    }

    @Test
    func `owner-object release is closure capture`() {
        final class Owner {}
        weak var observed: Owner?
        do {
            var retained: Owner? = Owner()
            observed = retained
            let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 16)
            let foreign = unsafe Memory.Foreign(adopting: unsafe .init(raw)) { [owner = retained] region in
                _ = owner
                unsafe region.base.nullable.deallocate()
            }
            retained = nil
            #expect(observed != nil, "the finalizer's capture keeps the owner alive")
            _ = foreign.capacity
        }
        #expect(observed == nil, "release of the envelope releases the owner")
    }
}

// MARK: - Integration

/// The other isolation domain.
///
/// The Foreign arrives as `consuming sending` and is dropped at the end of this
/// isolated method — the finalizer runs here, not where the value was made
/// ([MEM-SEND-010]/[MEM-SEND-012]; per-send region checking, no Sendable promise).
private actor Sink {
    func consume(_ foreign: consuming sending Memory.Foreign) {
        _ = foreign.capacity
    }
}

extension Memory.Foreign.Test.Integration {
    @Test
    func `non-Sendable Foreign crosses isolation as consuming sending and finalizes exactly once`() async {
        let census = Memory.Foreign.Census()
        let foreign = Memory.Foreign.fixture(byteCount: 64, census: census)
        let sink = Sink()
        await sink.consume(foreign)
        #expect(census.invocations == 1)
    }
}
