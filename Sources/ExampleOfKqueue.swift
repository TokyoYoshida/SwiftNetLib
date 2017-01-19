#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func kqueueLib() -> Int32
{

    let tcpServer = try! TcpServer.tcpListen()


    let kqueue = try! Kqueue(maxEvents:100)
    let ev = try! EventNotifier(eventManager: kqueue, server: tcpServer)
    
    try! ev.serverLoopExample()
    
    
    return 0
}
