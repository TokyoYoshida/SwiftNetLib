import C7

public class TcpStream : HandledStream {
    let client:TcpClient

    init(client: TcpClient) {
         self.client = client
    }
    
    public var closed: Bool { get {
            return client.closed
        }
    }

    public func send(_ data: Data, timingOut deadline: Double) throws {
        try client.tcpWrite(sendbuf: data) // Todo
    }
    
    public func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {  // Todo for timingOut support
        guard let tcpData = try client.tcpRead() else {
            throw StreamError.closedStream(data:Data())
        }
        return tcpData.data
    }
    
    public func flush(timingOut deadline: Double) throws {
        // Do Nothing
    }

    public func close() throws {
        try client.tcpClose()
    }

    public func getSocket() -> Int32 {
        return self.client.getSocket();
    }
}
