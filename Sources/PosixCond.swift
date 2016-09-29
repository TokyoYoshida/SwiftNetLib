#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif


public class PosixCond {
    var cond = pthread_cond_t()
    
    init(){
        pthread_cond_init(&cond, nil)
    }
    
    public func broadcast() {
        pthread_cond_broadcast(&cond)
    }
    
    public func wait(mutex: PosixMutex){
        pthread_cond_wait(&cond, &mutex.mutex)
    }
    
    public func signal(){
        pthread_cond_signal(&cond)
    }
    
    deinit{
        pthread_cond_destroy(&cond)
    }
}
