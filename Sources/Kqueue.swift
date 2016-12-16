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
    let mutex = PosixMutex()
    var notifyWaiting = PosixCond()
    
    init(maxEvents: Int) throws {
        waitingCount = 0
        kq = kqueue()
        guard kq != -1 else {
            throw NotifyError.errno(errorNo: errno)
        }

        self.kevList = Array(repeating:kevent(), count: maxEvents)
    }
    
    func add(handler: SocketHandler) throws {
        try setKevent(with: handler.getSocket(), flags:EV_ADD);
    }

    func delete(handler: SocketHandler) throws {
        try setKevent(with: handler.getSocket(), flags:EV_DELETE);
    }

    func disable(handler: SocketHandler) throws {
        try setKevent(with: handler.getSocket(), flags:EV_DISABLE);
    }
    
    func enable(handler: SocketHandler) throws {
        try setKevent(with: handler.getSocket(), flags:EV_ENABLE);
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

    func blockUntilIntoWaitingState() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        notifyWaiting.wait(mutex: mutex){
            return self.isWaiting()
        }
        
        return
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
        
        mutex.lock()
        
        defer {
            mutex.unlock()
        }

        switch(flags){
        case EV_ADD, EV_ENABLE:
            let needSignal = !isWaiting()
            waitingCount += 1
            if(needSignal){
                notifyWaiting.signal()
            }
        case EV_DELETE, EV_DISABLE:
            waitingCount -= 1
        default:
            assert(false, "This block is expected to be not called.")
        }
    }
}
