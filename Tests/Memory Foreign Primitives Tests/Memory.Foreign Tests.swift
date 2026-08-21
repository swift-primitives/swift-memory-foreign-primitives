import Memory_Foreign_Primitives
import Memory_Foreign_Primitives_Test_Support
import Testing

extension Memory.Foreign {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

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

extension Memory.Foreign.Test.`Edge Case` {
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
            let foreign = unsafe Memory.Foreign(adopting: unsafe .init(raw)) {
                [owner = retained] region in
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

private actor Sink {}

extension Sink {
    func consume(_ foreign: consuming sending Memory.Foreign) {
        _ = foreign.capacity
    }
}

extension Memory.Foreign.Test.Integration {
    @Test
    func `non-Sendable Foreign crosses isolation as consuming sending and finalizes exactly once`()
        async
    {
        let census = Memory.Foreign.Census()
        let foreign = Memory.Foreign.fixture(byteCount: 64, census: census)
        let sink = Sink()
        await sink.consume(foreign)
        #expect(census.invocations == 1)
    }
}
