#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

import C7

public enum TcpClientError: ErrorProtocol {
    case errno(errorNo: Int32)
}


public class TcpClient : SocketHandler{
    private  var socketfd: Int32
    internal var closed:   Bool    = true // TODO avoid state management

    static let DEFAULT_HOST        = "127.0.0.1"
    static let DEFAULT_PORT:UInt16 = 5188
    
    init(socketfd: Int32){
        self.socketfd = socketfd
        closed = false
    }
    
    private init(host: String, port: UInt16) throws {

        socketfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        if (socketfd < 0) {
            throw Error.errno(errorNo: errno)
        }
        





        var serveraddr             = sockaddr_in()
        serveraddr.sin_family      = UInt8(AF_INET)
        serveraddr.sin_port        = UInt16(bigEndian: port)
        serveraddr.sin_addr.s_addr = inet_addr(host)
        let serverPointer:UnsafePointer<sockaddr> = withUnsafePointer(&serveraddr) { UnsafePointer($0) }

        ret = connect(socketfd, serverPointer, UInt32(sizeofValue(serveraddr)))
        if (ret < 0) {
            throw TcpClientError.errno(errorNo: errno)
        }
 

        closed = false
    }

    public class func tcpOpen(host: String = DEFAULT_HOST, port: UInt16 = DEFAULT_PORT) throws -> TcpClient {

        return try TcpClient(host: host, port: port)
    }

    public func tcpRead() throws -> TcpData? {
        let recvbuf = TcpData()
        let size = recv(self.socketfd, recvbuf.pointer ,recvbuf.lenBytes, 0)
        
        guard size != -1 else {
            throw TcpClientError.errno(errorNo: errno)
        }

        guard size != 0 else {

            closed = true
            return nil
        }

        return recvbuf.truncated(size: size)
    }

    public func tcpWrite(sendbuf: TcpData) throws -> Int {
        let size = write(socketfd, sendbuf.pointer, sendbuf.lenBytes)

        guard size != -1 else {
            throw TcpClientError.errno(errorNo: errno)
        }

        return size
    }

    public func tcpWrite(sendbuf: Data) throws -> Int {
        guard sendbuf.bytes.count != 0 else {
            return 0
        }
        let size = send(socketfd, UnsafeMutablePointer(sendbuf.bytes), sendbuf.bytes.count * sizeofValue(sendbuf.bytes[0]), 0)
        
        guard size != -1 else {
            throw TcpClientError.errno(errorNo: errno)
        }
        
        return size
    }

    public func tcpClose() throws {
        closed = true
        guard close(socketfd) != -1 else {
            throw TcpClientError.errno(errorNo: errno)
        }
    }
    
    public func getSocket() -> Int32 {
        return self.socketfd;
    }
}
