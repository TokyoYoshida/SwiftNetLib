#if os(OSX)
    import Darwin
    import Foundation
#elseif os(Linux)
    import Glibc
#endif

class Kqueue {
    static let DEFAULT_HOST = "127.0.0.1"

    var kq:Int32
    var kevList:[kevent]
    var timeout:timespec
    var tcpServer:TcpServer
    
    enum Error: ErrorProtocol {
        case errno(errorNo: Int32)
    }
    
    
    init(tcpServer: TcpServer,maxEvents: Int,timeout:timespec) throws {
        self.tcpServer = tcpServer
        self.timeout   = timeout
        kq = kqueue()
        guard kq != -1 else {
            throw Error.errno(errorNo: errno)
        }

        var kev    = kevent()
        kev.ident  = UInt(tcpServer.getSocket());
        kev.filter = Int16(EVFILT_READ);
        kev.flags  = UInt16(EV_ADD);
        kev.fflags = 0;
        kev.data   = 0;

        guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
            throw Error.errno(errorNo: errno)
        }

        self.kevList = Array(repeating:kevent(), count: maxEvents)
    }
    
    func serverLoop() throws {
        while(true){
            let n = kevent(kq, nil, 0, &kevList, Int32(sizeofValue(kevList)/sizeofValue(kevList[0])), &timeout);
            for i in 0..<Int(n) {
                let sock = kevList[i].ident
                if ( sock == UInt(self.tcpServer.getSocket()) ){
                    let client = tcpServer.tcpAccept()

                    var kev    = makeKevent(with: tcpServer.getSocket()); // TODO local var is possible ?
                    guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
                        close(client.getSocket());
                        throw Error.errno(errorNo: errno)
                    }
                } else {
                    // TODO　client process
                }
                
            }
            
        }
    }

    func makeKevent(with socket:Int32) -> kevent {
        var kev    = kevent();
        kev.ident  = UInt(socket);
        kev.filter = Int16(EVFILT_READ);
        kev.flags  = UInt16(EV_ADD);
        kev.fflags = 0;
        kev.data   = 0;
        return kev;
    }
}
