#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func kqueueLib() -> Int32
{
//    let tcpServer = try! TcpServer(host: "127.0.0.1",port: 5188)
    let tcpServer = try! TcpServer.tcpListen()
//    var timeout = timespec()
//    timeout.tv_nsec = 100000;
    let kqueue = try! Kqueue(maxEvents:100)
    let ev = try! EventNotifier(eventManager: kqueue, tcpServer: tcpServer)
    
    try! ev.serverLoopExample()
    
    
    return 0
}
