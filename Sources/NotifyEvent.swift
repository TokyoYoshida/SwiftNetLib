#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

protocol SocketHandler {
    func getSocket()->Int32
}

protocol EventManager {
    func add(handler: SocketHandler) throws
    func wait(callBack: EventCallBackType) throws
}

typealias EventCallBackType = (socket: Int32) throws -> Void

public class EventNotifier {
    let eventManager: EventManager
    let tcpServer   : TcpServer
    
    enum Error: ErrorProtocol {
        case errno(errorNo: Int32)
    }

    init(eventManager: EventManager, tcpServer: TcpServer) throws {
        self.eventManager = eventManager
        self.tcpServer = tcpServer
        try eventManager.add(handler: tcpServer)
    }
    
    func wait(callBack: EventCallBackType) throws {
        try eventManager.wait(callBack: callBack)
    }

    func add(handler: SocketHandler) throws {
        try eventManager.add(handler: handler)
    }

    func serverLoopExample() throws {
        while(true){
            try eventManager.wait { sock in
                if ( sock == self.tcpServer.getSocket() ){
                    let client = self.tcpServer.tcpAccept()
                    
                    try self.eventManager.add(handler: client)
                } else {
                    let client = TcpClient(socketfd: Int32(sock))
                    
                    guard let recvbuf = try! client.tcpRead() else {
                        print("closed") // TODO
                        return
                    }
                    try! client.tcpWrite(sendbuf: recvbuf)
                }
                
            }
            
        }
    }
    

}
