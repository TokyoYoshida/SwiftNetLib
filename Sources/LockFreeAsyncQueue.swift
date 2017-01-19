#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif


import libkern

class ListHead {
    //    var prev:UnsafeMutableRawPointer? = nil
    var next:UnsafeMutablePointer<ListHead>? = nil
}

typealias UnsafeMutableRawPointer = UnsafeMutablePointer<Void>

class ListEntry<T> : Equatable {
    var listHead = ListHead()
    var value:T?
    
    init(_ value:T){
        self.value = value
    }
    
    init(){
        self.value = nil
    }
    
    func setNext(_ next:inout ListEntry<T>){
        listHead.next = withUnsafePointer(&next.listHead) { UnsafeMutablePointer<ListHead>($0) }
    }
    
    func getNext() -> ListEntry<T>?{
        guard listHead.next != nil else {
            return nil
        }
        let np = listHead.next!
        //        let np = unsafeBitCast(listHead.next, to: UnsafeMutableRawPointer.self)
        return get(from: np)
    }
    
    func get(from listHead: UnsafeMutablePointer<ListHead>) -> ListEntry<T> {
        let selfp = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
        let headp =  withUnsafePointer(&self.listHead){ UnsafeMutableRawPointer($0) }
        let listHeadp = UnsafeMutableRawPointer(listHead)
        
        let step = headp - selfp
        let p = listHeadp - step
        let r = unsafeBitCast(p, to: ListEntry<T>.self)
        return r
    }
}

func == <T>(lhs: ListEntry<T>, rhs: ListEntry<T>) -> Bool {
    return lhs == rhs
}

class LockFreeAsyncQueue<T>: AsyncQueueType<T> {
    var head:UnsafeMutablePointer<ListHead>?
    var tail:UnsafeMutablePointer<ListHead>?
    let initEnt = ListEntry<T>()
    var closed:Bool
    var aborted:Bool
    
    override init(){
        closed = false
        aborted = false
        let nhp = withUnsafePointer(&initEnt.listHead) {
            UnsafeMutablePointer<ListHead>($0) }
        _ = Unmanaged.passRetained(initEnt)
        
        self.head = nhp
        self.tail = nhp
    }
    
    deinit {
        _ = Unmanaged.passUnretained(initEnt)
    }
    
    override func put(obj: T) throws {
        let newentv = ListEntry(obj)
        _ = Unmanaged.passRetained(newentv)
        let newenthp = withUnsafePointer(&newentv.listHead) { UnsafeMutablePointer<ListHead>($0)}
        
        while(true){
            let last = self.tail!.pointee
            let lastp = self.tail
            let nextp = last.next
            


            if(closed) {
                throw AsyncQueueError.closedException
            }
            
            if(aborted) {
                throw AsyncQueueError.abortedException
            }

            if lastp != self.tail {
                continue
            }
            
            if nextp == nil {
                if compareAndSwap(oldp: nextp, newp: newenthp, targetp: &last.next) {
                    compareAndSwap(oldp: lastp, newp: newenthp, targetp: &self.tail )

                    return
                }
            } else {
                compareAndSwap(oldp: lastp, newp: nextp, targetp: &self.tail )
            }
            
        }
    }
    
    override func get() throws -> T?  {
        while(true){
            let first = self.head!.pointee
            let firstp = self.head
            let lastp = self.tail
            let nextp = first.next
            
            if(aborted) {
                throw AsyncQueueError.abortedException
            }
            
            if firstp != self.head {
                continue
            }
            
            if firstp == lastp {
                if( closed){
                    return nil
                }
                
                if nextp == nil {
                    while(true){
                        let fp = self.head!.pointee
                        if fp.next != nil {
                            break
                        }
                        usleep(1);
                    }
                    continue
                }
                compareAndSwap(oldp: lastp, newp: nextp, targetp: &self.tail )
            } else {
                let nv = initEnt.get(from: first.next! ).value
                if compareAndSwap(oldp: firstp, newp: nextp, targetp: &self.head ) {
                    _ = Unmanaged.passUnretained(first)
                    return nv
                }
            }
        }
    }
    
    @discardableResult
    private func compareAndSwap(oldp: UnsafeMutablePointer<ListHead>?, newp: UnsafeMutablePointer<ListHead>? ,targetp: inout UnsafeMutablePointer<ListHead>?) -> Bool{
        let op = UnsafeMutableRawPointer(oldp)
        let np = UnsafeMutableRawPointer(newp)
        let trp = OpaquePointer( withUnsafePointer(&targetp) { UnsafeMutableRawPointer($0) } )
        let tp = UnsafeMutablePointer<UnsafeMutableRawPointer?>(trp)
        let r =  OSAtomicCompareAndSwapPtrBarrier(op, np, tp)
        return r
    }
    
    override func close(){
        closed = true
    }
    
    override func abort(){
        self.aborted = true;
    }
}
