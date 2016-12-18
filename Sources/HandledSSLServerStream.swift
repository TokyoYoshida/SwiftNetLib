import OpenSSL

public class HandledSSLServerStream: HandledStream {
    let sslStream:SSLServerStream
    let rawStream: HandledStream
    
    public var closed: Bool = false

    public init(context: SSLServerContext, rawStream: HandledStream) throws {
        self.rawStream = rawStream
        self.sslStream = try SSLServerStream(context: context, rawStream: rawStream)
    }
    
    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {
        return try self.sslStream.receive(upTo: byteCount, timingOut: deadline)
    }
    
    public func send(_ data: Data, timingOut deadline: Double) throws {
        try self.sslStream.send(data, timingOut: deadline)
    }
    
    public func flush(timingOut deadline: Double) throws {
        try self.sslStream.flush(timingOut: deadline)
    }
    
    public func close() throws {
        try self.sslStream.close()
    }
    
    public func getSocket()->Int32 {
        return self.rawStream.getSocket()
    }
}
