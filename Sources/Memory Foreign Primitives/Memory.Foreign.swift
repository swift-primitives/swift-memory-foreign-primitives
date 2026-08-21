public import Memory_Primitive
public import Span_Raw_Primitives

extension Memory {

    @frozen
    public struct Foreign: ~Copyable {

        @usableFromInline
        internal let _region: Span.Raw.Mutable

        @usableFromInline
        internal var _finalizer: ((Span.Raw.Mutable) -> Void)?

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

    @inlinable
    public consuming func take() -> (
        region: Span.Raw.Mutable,
        finalizer: (Span.Raw.Mutable) -> Void
    ) {

        let finalizer = _finalizer!
        _finalizer = nil
        return (_region, finalizer)
    }
}
