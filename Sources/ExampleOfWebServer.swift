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
        let tcpServer = try TcpServer.tcpListen()
        let errorCallBack:ErrorCallBack = { error in
            return Response(body: Data("error page."))
        }

        let kqueue = try! Kqueue(maxEvents:100)
        let ev = try! EventNotifier(eventManager: kqueue, tcpServer: tcpServer)

        let queue = AsyncQueue<SwiftThreadFunc>(size:100)
        
        let consumer = ThreadPoolConsumer(queue: queue)
        try! consumer.makePoolThreads(numOfThreads:7)

        let server =     HttpServer(
            tcpListener:   tcpServer,
            errorCallBack: errorCallBack,
            responder:      MyResponder(),
            eventNotifier: ev,
            threadPoolQueue: queue
        )

        server.use(add_middleware: MyMiddleware())

        let wsServer = WebSocketServer { req, ws in
            print("connected")

            ws.onBinary { data in
                print("data: \(data)")
                try ws.send("server reply : " + data)
            }
            ws.onText { text in
                print("data: \(text)")
                try ws.send("server reply : " + text)
            }
        }

        server.use(add_middleware:wsServer)

        try server.serve()
    } catch {
        print("error")
    }

    return 0
}
