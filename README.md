# Memory Foreign Primitives

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

The owning envelope for foreign memory — a move-only `Memory.Foreign` value that pairs a non-owning raw descriptor with a provider-supplied finalizer, releasing bytes this process did not allocate exactly once on drop.

---

## Quick Start

`Memory.Foreign` is the third ownership regime: not memory you allocated (the heap), not memory you are only borrowing (a `Span`), but a located run of raw bytes a provider handed you — a pool slot, a C library buffer, a kernel-provided buffer — that you own past the lending scope and release by invoking *their* callback, never by `deallocate`. It is the institute shape of the pattern production datapaths converge on (FreeBSD `m_ext_free_t`, Linux `skb` destructors, DPDK external-buffer callbacks, io_uring provided buffers): a per-buffer release callback owned by the buffer value, with `~Copyable` uniqueness making exactly-once release structural rather than refcounted.

```swift
import Memory_Foreign_Primitives

// A buffer this process did NOT allocate — handed over by a pool, a C
// library, or the kernel — together with the provider's release callback.
let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: 4096, alignment: 16)

// Adopt it: Memory.Foreign now OWNS those bytes. The unsafety is the
// ownership claim, not the pointer — the adopter asserts exclusive,
// stable, writable custody until the finalizer runs.
let foreign = unsafe Memory.Foreign(adopting: unsafe .init(raw)) { region in
    unsafe region.base.nullable.deallocate()   // the provider's release path
}

// Use it through the Memory.Region seam: a located run of raw bytes.
let start = foreign.base                        // Memory.Address of byte 0
print(foreign.capacity.underlying)              // 4096

// No explicit free. Dropping `foreign` invokes the finalizer exactly once;
// move-only uniqueness makes the 1:1 buffer-to-consumer custody structural.
```

Custody can also be transferred out without releasing — for re-wrapping at a representation boundary. `take()` consumes the value and hands back the region and finalizer; the next adopter inherits the exactly-once responsibility:

```swift
import Memory_Foreign_Primitives

let foreign = unsafe Memory.Foreign(adopting: unsafe .init(raw)) { region in
    unsafe region.base.nullable.deallocate()
}

// Move custody out instead of dropping. The deinit does not double-run.
let (region, finalizer) = foreign.take()
finalizer(region)   // release happens here, exactly once
```

`Memory.Foreign` is deliberately not `Sendable`: the finalizer can capture state the type cannot see, so isolation crossing is checked per send — boundary APIs take `consuming sending Memory.Foreign`. A finalizer that captures only disconnected state forms a disconnected region and crosses freely; isolated captures are rejected at the send site.

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-primitives/swift-memory-foreign-primitives.git", branch: "main")
]
```

```swift
.target(
    name: "App",
    dependencies: [
        .product(name: "Memory Foreign Primitives", package: "swift-memory-foreign-primitives"),
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26 (or the matching Linux / Windows toolchain).

---

## Architecture

Two library products. Depends only on the `Memory` and `Span.Raw` primitives.

| Product | Target | Purpose |
|---------|--------|---------|
| `Memory Foreign Primitives` | `Sources/Memory Foreign Primitives/` | The `Memory.Foreign` owning envelope: `@unsafe` adoption (`init(adopting:finalizer:)`), exactly-once release on drop, custody transfer (`take()`), and the `Memory.Region` conformance exposing `base` and `capacity`. |
| `Memory Foreign Primitives Test Support` | `Tests/Support/` | Re-exports the main target and adds census / fixture helpers for exercising release semantics in test consumers. |

Foundation-free.

---

## Platform Support

| Platform | Status |
|----------|--------|
| macOS 26 | Full support |
| Linux | Full support |
| Windows | Full support |
| iOS / tvOS / watchOS / visionOS | Supported |

---

## Community

<!-- BEGIN: discussion -->
<!-- Discussion thread created at publication. -->
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE.md](LICENSE.md).
