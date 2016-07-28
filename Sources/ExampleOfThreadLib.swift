#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func threadLib() -> Int32
{
    print("thread1 kick.")

    for x in 0...100 {
        print("loop\(x)")
        let thread1 = try! Thread.new {
            print("this is thread1.")
            
            print("thread3 kick.")
            let thread3 = try! Thread.new {
                
                print("this is thread3.")
                
                print("thread3 end.")
            }
            
            print("thread3 join.")
            
            try! thread3.join()
            
            print("thread1 end.")
        }
        try! thread1.join()
    }
    
//    semaphore2.wait()
    

    print("thread2 kick.")
    
    let thread2 = try! Thread.new {
        
        print("this is thread2.")
        
//        semaphore1.post()
    }
    

    print("thread2 join.")
    try! thread2.join()
//    pthread_exit(nil)

    return 0
}

func threadServerLib() -> Int32{
    print("threadServerLib mode.")
    
    do {
        let server = try TcpServer.tcpListen()
        
        while(true){
            let client = server.tcpAccept()
            _ = try Thread.new {
                while(true){
                    do {
                        guard let recvbuf = try client.tcpRead() else {
                            break
                        }
                        try client.tcpWrite(sendbuf: recvbuf)
                        if let str = recvbuf.description  {
                            print(str)
                        }
                    } catch {
                        print("error")
                    }
                }
            }
        }
    } catch {
        print("error")
    }
    
    return 0
}