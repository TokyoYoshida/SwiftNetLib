#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif
import OpenSSL


public class TlsServer : ServerType  {
//    private var listenfd: Int32
    let server: ServerType
    let sslContext: SSLServerContext
    
    public init(server: ServerType,certificate: String, privateKey: String, certificateChain: String? = nil)  throws {
        self.server = server
        sslContext = try SSLServerContext(
            certificate: certificate,
            privateKey: privateKey,
            certificateChain: certificateChain)
        
    }
    
    public func accept() throws -> HandledStream {
        let stream = try server.accept()
        return try HandledSSLServerStream(context: sslContext, rawStream: stream)
    }

    public func getSocket()->Int32 {
        return server.getSocket()
    }
}
