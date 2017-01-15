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
    var notifyWaiting = PosixCond()
    
    init(maxEvents: Int) throws {
        kq = kqueue()
        guard kq != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }

        self.kevList = Array(repeating:kevent(), count: maxEvents)
    }
    
    func add(socket: Int32) throws {
        try setKevent(with: socket, flags:EV_ADD);
    }

    func delete(socket: Int32) throws {
        try setKevent(with: socket, flags:EV_DELETE);
    }
    
    func clear(socket: Int32) throws {
        try setKevent(with: socket, flags:EV_CLEAR);
    }

    func disable(socket: Int32) throws {
        try setKevent(with: socket, flags:EV_DISABLE);
    }
    
    func enable(socket: Int32) throws {
        try setKevent(with: socket, flags:EV_ENABLE);
    }

    func wait(callBack: EventCallBackType ) throws {
        let n = kevent(kq, nil, 0, &kevList, Int32(kevList.count), nil);

        guard n != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }

        for i in 0..<Int(n) {
            let sock = kevList[i].ident

            try callBack(handler: Int32(sock))
        }
    }
    
    private func setKevent(with socket:Int32, flags: Int32) throws {
        var kev    = kevent();
        kev.ident  = UInt(socket);
        kev.filter = Int16(EVFILT_READ);
        kev.flags  = UInt16(flags);
        kev.fflags = 0;
        kev.data   = 0;

        guard kevent(kq, &kev, 1, nil, 0, nil) != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }
        
    }
}
