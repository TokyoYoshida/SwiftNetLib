#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func tcpLibClient() -> Int32
{
    print("tcpLib client mode")
    
    do {
        
        let client = try TcpClient.tcpOpen()
        
        let sendbuf = TcpData()
        
        while fgets(sendbuf.pointer, Int32(sendbuf.lenBytes), stdin) != nil {
            try! client.tcpWrite(sendbuf: sendbuf)
            guard let recvbuf = try! client.tcpRead() else {
                try! client.tcpClose()
                break
            }
            fputs(recvbuf.pointer, stdout)
        }
    } catch {
        print("error file : \(#file) line : \(#line)")
    }
    
    return 0
}

func tcpLibServer() -> Int32
{
    print("tcpLib server mode")
    
    let server = try! TcpServer.tcpListen()
    
    let client = server.tcpAccept()
    
    while(true) {
        guard let recvbuf = try! client.tcpRead() else {
            break
        }
        try! client.tcpWrite(sendbuf: recvbuf)
        if let str:String = recvbuf.description  {
            print(str)
        }
    }
    
    return 0
}

