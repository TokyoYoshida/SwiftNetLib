#if os(OSX)
    import Darwin
    let os_accept = Darwin.accept
#elseif os(Linux)
    import Glibc
    let os_accept = Glibc.accept
#endif

public class TcpServer : ServerType  {
    private var listenfd: Int32
    
    static let DEFAULT_HOST = "127.0.0.1"
    static let DEFAULT_PORT:UInt16 = 5188

    public init(host: String, port: UInt16) throws {
        listenfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        if (listenfd < 0) {
            throw Error.errno(errorNo: errno)
        }
        
        var serveraddr = sockaddr_in()
        memset(&serveraddr, 0, sizeofValue(serveraddr))
        serveraddr.sin_family = UInt8(AF_INET)
        serveraddr.sin_port = UInt16(bigEndian: port)
        serveraddr.sin_addr.s_addr = inet_addr(host)
        let serverPointer:UnsafePointer<sockaddr> = withUnsafePointer(&serveraddr) { UnsafePointer($0) }
        
        var on = 1
        try throwErrorIfFailed { [unowned self] in
            return setsockopt(self.listenfd, SOL_SOCKET, SO_REUSEADDR, &on, UInt32(sizeofValue(on)))
        }
        
        try throwErrorIfFailed { [unowned self] in
            return bind(self.listenfd, serverPointer, UInt32(sizeofValue(serveraddr)))
        }

        try throwErrorIfFailed { [unowned self] in 
            return listen(self.listenfd, SOMAXCONN)
        }
        
    }

    public class func tcpListen(host: String = DEFAULT_HOST, port: UInt16 = DEFAULT_PORT) throws -> TcpServer {
        
        return try TcpServer(host: host, port: port)
    }
    
    public func tcpAccept() throws -> TcpClient {
        var connectfd:Int32
        var peeraddr = sockaddr_in()
        var peeraddr_len = socklen_t(sizeofValue(peeraddr))
        let peerPointer:UnsafeMutablePointer<sockaddr> = withUnsafePointer(&peeraddr) { UnsafeMutablePointer($0) }

        connectfd = os_accept(listenfd, peerPointer, &peeraddr_len)
        if (connectfd < 0) {
            throw Error.errno(errorNo: errno)
        }
        
        if let addr =  String(validatingUTF8: inet_ntoa(peeraddr.sin_addr)) {
            print("accept : \(addr):\(peeraddr.sin_port)\n")
        }

        return TcpClient(socketfd: connectfd)
    }
    
    public func tcpClose(){
        close(listenfd)
    }
    
    public func getSocket()->Int32 {
        return self.listenfd
    }
    
    private func throwErrorIfFailed(targetClosure: ()->Int32) throws {
        
        let returnValue = targetClosure()
        
        guard returnValue == 0 else {
            throw Error.errno(errorNo: returnValue)
        }
    }

    public func accept() throws -> HandledStream {
        return TcpStream(client: try tcpAccept())
    }
    
    public func createStream(socket: Int32) -> HandledStream {
        return TcpStream(client: TcpClient(socketfd: socket))
    }
}
