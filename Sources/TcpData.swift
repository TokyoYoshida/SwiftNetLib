#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif
import C7

public protocol DataType {
    var data:         Data                       {get}
    var lenBytes:     Int                        {get}
    var description : String?                    {get}
    var pointer:      UnsafeMutablePointer<Int8> {get}
}

public struct TcpData: DataType {
    public  var data:     Data
    
    public init(size: Int = 1024) {
        let bytes = [Byte](repeating: 0, count: size)
        self.data = Data(bytes)
    }
    
    public init(data: Data) {
        self.data = data
    }

    public func truncated(size: Int) -> TcpData {
        let newBytes = [Byte](repeating: 0, count: size)
        memcpy(UnsafeMutablePointer<Void>(newBytes), data.bytes, size)

        return TcpData(data: Data(newBytes))
    }

    public var pointer: UnsafeMutablePointer<Int8> {
        return UnsafeMutablePointer(data.bytes)
    }
    
    public var lenBytes: Int {
        return data.bytes.count * sizeofValue(data.bytes[0])
    }
    
    public var description: String? {
        return data.description
    }
}
    