public import Memory_Address_Primitives
public import Memory_Primitive
public import Memory_Region_Primitives
public import Span_Raw_Primitives

extension Memory.Foreign: Memory.Region {

    @inlinable
    public var base: Memory.Address {

        unsafe Memory.Address(_region.base.nonNull.baseAddress!)
    }

    @inlinable
    public var capacity: Memory.Address.Count {
        Memory.Address.Count(UInt(unsafe _region.base.nonNull.count))
    }
}
