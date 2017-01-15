#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

// TODO Since these signal processes have not been created yet, I made it temporarily.

func signalHandler(sign: Int32){
    print("Signal")
    // do nothing
    signal(SIGINT, signalHandler)
}

func setSignal() {
//    signal(SIGINT, signalHandler)
    signal(SIGPIPE, signalHandler)
}
