#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func signalHandler(sign: Int32){
    print("sigint")
    // do nothing
    signal(SIGINT, signalHandler)
}

func setSignal() {
    signal(SIGINT, signalHandler)
}
