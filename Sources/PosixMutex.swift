#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

public class PosixMutex {
    var mutex = pthread_mutex_t()
    
    init () {
        pthread_mutex_init(&mutex, nil)
    }
    
    public func lock(){
        pthread_mutex_lock(&mutex)
    }
    
    public func unlock(){
        pthread_mutex_unlock(&mutex)
    }
    
    public func destroy(){
        pthread_mutex_destroy(&mutex)
    }
    
    deinit {
        destroy()
    }
}

private let globalMutex = PosixMutex()
public func sync<A>(mutex: PosixMutex = globalMutex,  syncFunc:  () throws -> A) rethrows -> A {
    mutex.lock()
    
    defer {
        mutex.unlock()
    }
    
    let retValue = try syncFunc()
    
    return retValue
}
