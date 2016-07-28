#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif
import C7
import HTTPParser

func httpServer() -> Int32
{
    print("httpServer mode.")
    
    do {
        let tcpServer = try TcpServer.tcpListen()
        let errorCallBack:ErrorCallBack = { error in
            return Response(body: Data("error page."))
        }
        
        let server =     HttpServer(
            tcpListener: tcpServer,
            errorCallBack: errorCallBack )
        
        try server.serve { request in
            return Response(body: Data("this is test"))
        }
    } catch {
        print("error")
    }
    
    return 0
}

