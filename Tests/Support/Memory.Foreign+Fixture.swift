public import Memory_Foreign_Primitives

extension Memory.Foreign {

    public static func fixture(byteCount: Int, alignment: Int = 16, census: Census) -> Memory.Foreign {
        let raw = UnsafeMutableRawBufferPointer.allocate(byteCount: byteCount, alignment: alignment)
        return unsafe Memory.Foreign(adopting: unsafe .init(raw)) { region in
            unsafe region.base.nullable.deallocate()
            census.record()
        }
    }
}
