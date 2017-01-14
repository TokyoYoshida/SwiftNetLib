#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif
import C7
import S4
import HTTPParser
import WebSocketServer

class MyResponder : Responder {
    func respond(to request: Request) throws -> Response {
        return Response(body: Data("this is test"))
    }
}

class MyMiddleware : Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        print("this is Middleware.")
        return try next.respond(to:request)
    }
}

func httpServer() -> Int32
{
    print("httpServer mode.")

    do {
        print("st0")
        let queue = LockFreeAsyncQueue<SwiftThreadFunc>()
        
        let consumer = ThreadPoolConsumer(queue: queue)
        try! consumer.makePoolThreads(numOfThreads:7)

        let tcpServer = try TcpServer.tcpListen(port:5189)
        let tlsServer = try TlsServer(server: tcpServer, certificate:"/tmp/ssl/cert.pem", privateKey: "/tmp/ssl/server.key" )
        let errorCallBack:ErrorCallBack = { error in
            return Response(body: Data("error page."))
        }

        let kqueue = try! Kqueue(maxEvents:100)
        let ev = try! EventNotifier(eventManager: kqueue, server: tcpServer)


        let server1 =     HttpServer(
            tcpListener:   tlsServer,
            errorCallBack: errorCallBack,
            responder:      MyResponder(),
            eventNotifier: ev,
            threadPoolQueue: queue
        )

        server1.use(add_middleware: MyMiddleware())

        let wsServer = BroadcastableWebSocketServer { req, ws, wss in
            print("connected")

            ws.onBinary { data in
                print("data: \(data)")
                try ws.send("server reply : " + data)
            }
            ws.onText { text in
                print("data: \(text)")
                try ws.send("server reply1 : " + text)
                print("test wss num :\(wss.all.count)")
                try wss.all.forEach {
                    try $1.send("server reply2 : " + text)
                }
            }
            print("wss num :\(wss.all.count)")
        }

        print("st1")


        let tcpServer2 = try TcpServer.tcpListen()
        
        let kqueue2 = try! Kqueue(maxEvents:100)
        let ev2 = try! EventNotifier(eventManager: kqueue2, server: tcpServer2)
        
        let server2 =     HttpServer(
            tcpListener:   tcpServer2,
            errorCallBack: errorCallBack,
            responder:      MyResponder(),
            eventNotifier: ev2,
            threadPoolQueue: queue
        )
        
        print("st2")

        server2.use(add_middleware: MyMiddleware())
        
        server2.use(add_middleware:wsServer)

        try queue.put {
            do {
                try server1.serve()
            } catch {
                print("error server1")
            }
        }
        
        try server2.serve()
    } catch {
        print("error")
    }

    return 0
}
