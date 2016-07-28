#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
    #endif

typealias PosixThreadFunc = @convention(c)(UnsafeMutablePointer<Void>!) -> UnsafeMutablePointer<Void>!

public  typealias SwiftThreadFunc = () -> Void

public class ThreadUnit  {
    private var pthread = pthread_t(nil)
    
    public enum DetachState {
        case detached
        case joinable
    }
    
    public enum Error: ErrorProtocol {
        case errno(errorNo: Int32)
    }
    
    init(detachState: DetachState = .joinable,@noescape threadFunc: SwiftThreadFunc) throws {

        print("thread init")

        try create(detachState: detachState, threadFunc: threadFunc)

    }
    
    private func create(detachState: DetachState,  @noescape threadFunc: SwiftThreadFunc) throws {
    
        var threadDataBag = retainedVoidPointer(x: threadFunc)

        let thread_function:PosixThreadFunc =  { threadData in
            
            guard let threadFunc = unsafeFromVoidPointer(x:threadData) as SwiftThreadFunc! else {
                return nil
            }

            defer {
                releaseRetainedPointer(x: threadFunc)
            }
            
            threadFunc()
            
            return nil
        }
        
        var threadAttr = pthread_attr_t()

        try throwErrorIfFailed {
            return pthread_attr_init(&threadAttr)
        }

        try throwErrorIfFailed {
            return pthread_attr_setdetachstate(&threadAttr , PTHREAD_CREATE_JOINABLE)
        }
        
        try throwErrorIfFailed {
            return pthread_create(&pthread, nil, thread_function, threadDataBag)
        }
        
        try throwErrorIfFailed {
            return pthread_attr_destroy(&threadAttr)
        }
    }
    
    public func join() throws {
        try throwErrorIfFailed {
            return pthread_join(pthread, nil)
        }
    }
    
    deinit {
        print("thread deinit")
    }
    
    private func throwErrorIfFailed(@noescape targetClosure: ()->Int32) throws {
        
        let returnValue = targetClosure()
        
        guard returnValue == 0 else {
            throw Error.errno(errorNo: returnValue)
        }
    }
    
}

public class ThreadUnitContainer {
    private var threadUnits = [ThreadUnit]()
    private let mutex = PosixMutex()
    
    func add(detachState: ThreadUnit.DetachState, @noescape threadFunc: SwiftThreadFunc) throws  -> ThreadUnit {
        let newThread = try ThreadUnit(threadFunc: threadFunc)
        
        synchronized(mutex: mutex) { [unowned self] in
            self.threadUnits.append(newThread)
        }
        
        return newThread
    }
}

public class Thread {
    static let threadContainer = ThreadUnitContainer()
    
    public class func add(detachState: ThreadUnit.DetachState = ThreadUnit.DetachState.joinable, @noescape threadFunc: SwiftThreadFunc) throws -> ThreadUnit {
        return try threadContainer.add(detachState: detachState, threadFunc: threadFunc )
    }
    
    public class func new(detachState: ThreadUnit.DetachState = ThreadUnit.DetachState.joinable, @noescape threadFunc: SwiftThreadFunc) throws -> ThreadUnit {
        return try ThreadUnit(detachState: detachState, threadFunc: threadFunc)
    }
}
