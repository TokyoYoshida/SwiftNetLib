#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif



func signalHandler(sign: Int32){
    print("signal recieved.")
    // do nothing
    signal(SIGINT, signalHandler)
}

func setSignal() {

    signal(SIGPIPE, SIG_IGN)
}
