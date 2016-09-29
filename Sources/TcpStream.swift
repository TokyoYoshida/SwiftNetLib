import C7

class TcpStream : Stream {
    let client:TcpClient

    init(client: TcpClient) {
         self.client = client
    }
    var closed: Bool { get {
            print("check stream closed",client.closed)
            return client.closed
        }
    }

    func send(_ data: Data, timingOut deadline: Double) throws {
        try client.tcpWrite(sendbuf: data) // Todo
    }
    
    func receive(upTo byteCount: Int, timingOut deadline: Double) throws -> Data {  // Todo for timingOut support
        guard let tcpData = try client.tcpRead() else {
            throw StreamError.closedStream(data:Data())
        }
        return tcpData.data
    }
    
    func flush(timingOut deadline: Double) throws {} // Todo

    func close() throws {
        try client.tcpClose()
    }
}
