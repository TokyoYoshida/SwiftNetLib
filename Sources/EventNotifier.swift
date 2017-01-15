#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

public protocol SocketHandler {
    func getSocket()->Int32
}

public protocol EventManager {
    func add(socket: Int32) throws
    func delete(socket: Int32) throws
    func wait(callBack: EventCallBackType) throws
    func clear(socket: Int32) throws
    func disable(socket: Int32) throws
    func enable(socket: Int32) throws
}

public typealias EventCallBackType = (handler: Int32) throws -> Void

enum NotifyError: ErrorProtocol {
    case errno(errorNo: Int32)
}


public class EventNotifier {
    let eventManager: EventManager
    let server   : ServerType
    
    init(eventManager: EventManager, server: ServerType) throws {
        self.eventManager = eventManager
        self.server = server
        try eventManager.add(socket: server.getSocket())
    }
    
    func wait(callBack: EventCallBackType) throws {
        try eventManager.wait(callBack: callBack)
    }

    func add(socket: Int32) throws {
        try eventManager.add(socket: socket)
    }

    func delete(socket: Int32) throws {
        try eventManager.delete(socket: socket)
    }
    
    func clear(socket: Int32) throws {
        try eventManager.clear(socket: socket)
    }
    
    func disable(socket: Int32) throws {
        try eventManager.disable(socket: socket)
    }
    
    func enable(socket: Int32) throws {
        try eventManager.enable(socket: socket)
    }

    func serverLoopExample() throws {
        while(true){
            try eventManager.wait { sock in
                if ( sock == self.server.getSocket() ){
                    let client = try self.server.accept()
                    
                    try self.eventManager.add(socket: client.getSocket())
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
