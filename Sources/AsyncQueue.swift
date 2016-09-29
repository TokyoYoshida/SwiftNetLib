class AsyncQueue<T> {
    var queue = [T]()
    var mutex = PosixMutex()
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
    
    func put(obj: T){
    
    
    }
}
