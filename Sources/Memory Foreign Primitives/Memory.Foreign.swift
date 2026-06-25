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
public import Span_Raw_Primitives

extension Memory {
    /// The foreign regime leaf — the owning envelope around the ecosystem's non-owning
    /// raw descriptor.
    ///
    /// `Memory.Foreign` represents the third ownership regime: a located run of raw bytes
    /// this process did **not** allocate, owned past the lending scope, and released by
    /// invoking a provider-supplied finalizer — never by `deallocate`. It is the
    /// institute shape of the pattern every production datapath converges on (FreeBSD
    /// `m_ext_free_t`, Linux `skb` destructors, DPDK external-buffer callbacks; for
    /// io_uring provided buffers the callback is the consumer's own re-provide closure
    /// over the custody window): a per-buffer release callback owned by the buffer
    /// value, with `~Copyable` uniqueness replacing the hand-maintained refcount for
    /// 1:1 buffer-to-consumer custody — exactly-once release is structural, not
    /// counted. What refcounts additionally fund — N references sharing one region
    /// (DPDK external-buffer carving, `skb_clone`) — is deliberately out of this
    /// regime's scope; sharing, if ever wanted, is rebuilt at a higher tier.
    ///
    /// The value is `Span.Raw.Mutable` (the storable raw descriptor) + the finalizer +
    /// move-only ownership. Its entire tower integration is the `Memory.Region`
    /// conformance in `Memory.Foreign+Memory.Region.swift`.
    ///
    /// ## Adoption contract
    ///
    /// The adopting initializer is the `@unsafe` construction boundary. The unsafety is
    /// the **ownership claim**, not the parameter types: the adopter asserts that
    /// - the region is exclusively owned and writable for this value's lifetime
    ///   (read-only memory MUST NOT be adopted — it stays at the borrowing `Span` tier);
    /// - the bytes remain valid at a stable address until the finalizer runs;
    /// - the finalizer actually releases the region, exactly the region, and nothing else;
    /// - no other owner (here or in the provider) will release the same region.
    ///
    /// The region is byte-level. Element **alignment is the adopter's obligation at the
    /// storage-construction seam**: `Storage.Contiguous`'s `Memory.Region` initializer
    /// resolves the typed base with `assumingMemoryBound(to:)`, which is undefined
    /// behavior on a misaligned base. A `Span.Raw`-fed Foreign is byte-element in
    /// practice; non-byte adoption must carry its own alignment proof.
    ///
    /// ## Concurrency posture
    ///
    /// `Memory.Foreign` is deliberately **not** `Sendable` (terminal direction at birth,
    /// [MEM-SEND-013]): the finalizer field opens the value's region to captures the type
    /// cannot see, so the semantic-correctness test that `Memory.Heap`'s self-contained
    /// absorber conformance passes is exactly what Foreign fails. Isolation crossing is
    /// region-checked per send — boundary APIs take `consuming sending Memory.Foreign`
    /// ([MEM-SEND-010]/[MEM-SEND-012]). A value whose finalizer captures only
    /// Sendable/disconnected state forms a disconnected region and crosses freely;
    /// isolated captures are rejected at the send site.
    ///
    /// An owner-object release needs no second mechanism: capturing the owner in the
    /// finalizer (`{ _ in _ = owner }`) retains it until release, and a pool's recycle
    /// closure is created once and retained per adoption.
    ///
    /// ## Layout note
    ///
    /// `@frozen` per [API-IMPL-022] (tower value types ship `@frozen` from birth):
    /// without it, cross-module consuming decomposition — exactly `take()`'s shape — is
    /// illegal. Layout solidifies at first tag (none this phase), so the Optional
    /// finalizer field — a workaround for `discard self` requiring trivially-destroyed
    /// stored properties "at this time" — can still be retired pre-publication if the
    /// toolchain wall falls.
    ///
    /// Design: `swift-institute/Research/memory-foreign-and-memory-protocol.md` (v1.1.0).
    @frozen
    public struct Foreign: ~Copyable {
        /// The adopted region — the non-owning descriptor this value owns the bytes of.
        @usableFromInline
        internal let _region: Span.Raw.Mutable

        /// The provider-supplied release callback, invoked exactly once with the region.
        ///
        /// Optional SOLELY so `take()` can suppress the deinit's invocation: `discard
        /// self` requires trivially-destroyed stored properties, so a closure-bearing
        /// `~Copyable` uses the guarded-deinit shape instead (precedent:
        /// `Completion.Entry`). `nil` is reachable only via `take()`, which consumes
        /// `self` — every live value holds a finalizer.
        @usableFromInline
        internal var _finalizer: ((Span.Raw.Mutable) -> Void)?

        /// Adopts a foreign region, claiming ownership of its bytes and registering the release callback.
        ///
        /// See the type-level Adoption contract for the obligations this claim asserts.
        ///
        /// - Precondition: `region` is non-empty. An empty descriptor aliases the shared
        ///   empty-span sentinel, which must never reach a finalizer.
        @unsafe @inlinable
        public init(
            adopting region: Span.Raw.Mutable,
            finalizer: @escaping (Span.Raw.Mutable) -> Void
        ) {
            precondition(!region.isEmpty, "Memory.Foreign cannot adopt an empty region")
            self._region = region
            self._finalizer = finalizer
        }

        deinit {
            if let finalizer = _finalizer { finalizer(_region) }
        }
    }
}

extension Memory.Foreign {
    /// Transfers custody out without invoking the finalizer, for re-wrapping at
    /// representation boundaries.
    ///
    /// The ownership claim made at adoption travels with the returned pair; the
    /// caller (or the next adopter) becomes responsible for exactly-once release.
    @inlinable
    public consuming func take() -> (
        region: Span.Raw.Mutable,
        finalizer: (Span.Raw.Mutable) -> Void
    ) {
        // A live value always holds a finalizer (`_finalizer` is nil only after
        // `take()`, and `take()` consumes self), so the unwrap cannot fail.
        // swift-format-ignore: NeverForceUnwrap
        let finalizer = _finalizer!
        _finalizer = nil
        return (_region, finalizer)
    }
}
