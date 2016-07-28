#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

public final class Box<A> {
    let value: A
    init(_ value: A) { self.value = value }
}

func unsafeFromVoidPointer<A>(x: UnsafeMutablePointer<Void>?) -> A? {
    guard let x = x else {
        return nil
    }
    return Unmanaged<Box<A>>.fromOpaque(OpaquePointer(x)).takeUnretainedValue().value
}

func releaseRetainedPointer<A>(x: A?) -> Void {
    guard let x = x else {
        return
    }
    let unmanaged = Unmanaged.passUnretained(Box(x))
    
    unmanaged.release()
}


func retainedVoidPointer<A>(x: A?) -> UnsafeMutablePointer<Void> {
    guard let value = x else {
        return UnsafeMutablePointer<Void>(allocatingCapacity: 0)
    }
    
    let unmanaged = OpaquePointer(bitPattern: Unmanaged.passRetained(Box(value)))
    
    return UnsafeMutablePointer(unmanaged)
}

func retainedVoidPointerFunc(x: PosixThreadFunc?) -> UnsafeMutablePointer<PosixThreadFunc> {
    guard let value = x else {
        return UnsafeMutablePointer<PosixThreadFunc>(allocatingCapacity: 0)
    }
    
    let unmanaged = OpaquePointer(bitPattern: Unmanaged.passRetained(Box(value)))
    
    return UnsafeMutablePointer(unmanaged)
}

