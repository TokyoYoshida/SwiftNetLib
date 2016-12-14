#if os(OSX)
    import Darwin
    import Foundation
#elseif os(Linux)
    import Glibc
#endif

class Kqueue : EventManager {
    static let DEFAULT_HOST = "127.0.0.1"

    let kq        :Int32
    var kevList   :[kevent]
    var waitingCount: Int
    
    init(maxEvents: Int) throws {
        waitingCount = 0
        kq = kqueue()
        guard kq != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }

        self.kevList = Array(repeating:kevent(), count: maxEvents)
    }
    
    func add(handler: SocketHandler) throws {
        waitingCount += 1

        var kev    = makeKevent(with: handler.getSocket(), flags:EV_ADD);

        guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }
    }

    func delete(handler: SocketHandler) throws {
        waitingCount += 1
        
        var kev    = makeKevent(with: handler.getSocket(), flags:EV_DELETE);
        
        guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }
    }

    func disable(handler: SocketHandler) throws {
        waitingCount -= 1

        var kev    = makeKevent(with: handler.getSocket(), flags:EV_DISABLE);
        
        guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }
    }
    
    func enable(handler: SocketHandler) throws {
        waitingCount += 1
        
        var kev    = makeKevent(with: handler.getSocket(), flags:EV_ENABLE);
        
        guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }
    }

    func wait(callBack: EventCallBackType ) throws {
        let n = kevent(kq, nil, 0, &kevList, Int32(kevList.count), nil);

        guard n != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }

        for i in 0..<Int(n) {
            let sock = kevList[i].ident

            try callBack(socket: Int32(sock))
        }
    }
    
    func isWaiting() -> Bool{
        return waitingCount > 0
    }
    
    func makeKevent(with socket:Int32, flags: Int32) -> kevent {
        var kev    = kevent();
        kev.ident  = UInt(socket);
        kev.filter = Int16(EVFILT_READ);
        kev.flags  = UInt16(flags);
        kev.fflags = 0;
        kev.data   = 0;
        return kev;
    }
}
