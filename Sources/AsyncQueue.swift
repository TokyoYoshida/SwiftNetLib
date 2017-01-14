enum AsyncQueueError : ErrorProtocol {
    case closedException
    case abortedException
}

protocol AsyncQueueTypeBase {
    associatedtype BT
    func put(obj: BT) throws
    func get() throws -> BT?
    func close()
    func abort()
}

class  AsyncQueueType<T> : AsyncQueueTypeBase{
    typealias BT = T

    func put(obj: BT) throws {
        assert(false, "This block is expected to be not called.")
    }
    func get() throws -> BT? {
        assert(false, "This block is expected to be not called.")
    }
    func close() {
        assert(false, "This block is expected to be not called.")
    }
    func abort() {
        assert(false, "This block is expected to be not called.")
    }
}

class AsyncQueue<T> : AsyncQueueType<T> {
    var queue = [T]() // todo : list is more better than array
    let mutex = PosixMutex()
    var notifyNotFull = PosixCond()
    var notifyNotEmpty = PosixCond()
    var size:Int
    var closed:Bool
    var aborted:Bool
    
    init(size: Int){
        self.size = size
        closed    = false
        aborted   = false
    }
    
    override func put(obj: T) throws {
        mutex.lock()

        defer {
            mutex.unlock()
        }
        
        notifyNotFull.wait(mutex: mutex){
            return self.queue.count < self.size || self.closed || self.aborted;
        }
        
        if(closed) {
            throw AsyncQueueError.closedException
        }

        if(aborted) {
            throw AsyncQueueError.abortedException
        }
        
        let needSignal = queue.count == 0

        queue += [obj]
        
        if(needSignal){
            notifyNotEmpty.signal()
        }
    }
    
    override func get() throws -> T? {
        mutex.lock()
        
        defer {
            mutex.unlock()
        }
        
        notifyNotEmpty.wait(mutex: mutex){
            return self.queue.count != 0 || (self.queue.count == 0 && self.closed) || self.aborted;
        }
        
        if(self.queue.count == 0 && closed) {
            return nil
        }
        
        if(aborted) {
            throw AsyncQueueError.abortedException
        }
        
        let needSignal = queue.count == size
        
        let ret = queue[0]
        queue.remove(at: 0)
        
        if(needSignal){
            notifyNotFull.signal()
        }
        
        return ret
    }

    override func close(){
        mutex.lock()
        
        defer {
            mutex.unlock()
        }
        
        self.closed = true;
        
        self.notifyNotEmpty.broadcast()
        self.notifyNotFull.broadcast()
    }

    override func abort(){
        mutex.lock()
        
        defer {
            mutex.unlock()
        }
        
        self.aborted = true;
        
        self.notifyNotEmpty.broadcast()
        self.notifyNotFull.broadcast()
    }
}
