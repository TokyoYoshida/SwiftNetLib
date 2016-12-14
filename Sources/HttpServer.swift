import C7
import S4
import HTTPParser
import Foundation

protocol HttpServable {
    func serve() throws
}

typealias ErrorCallBack = (error: ErrorProtocol) -> Response?

// typealias Responder = (request: Request) -> Response?

class HttpServer : HttpServable {
    private let tcpListener:     TcpServer
    private let parser:          HttpRequestParsable
    private let serializer:      HTTPResponseSerializable
    private let errorCallBack:   ErrorCallBack
    private let mutex =          PosixMutex()
    private var middleware:      [Middleware]
    private let responder:       Responder
    private let eventNotifier:   EventNotifier
    private let threadPoolQueue: AsyncQueue<SwiftThreadFunc>
    private var processors:      [Int32:HttpProcessor]
    
    init(tcpListener:   TcpServer,
         parser:        HttpRequestParsable = HttpRequestParser(),
         serializer:    HTTPResponseSerializable = HTTPResponseSerializer(),
         middleware:    [Middleware] = [],
         errorCallBack: ErrorCallBack,
         responder:     Responder,
         eventNotifier:  EventNotifier,
         threadPoolQueue:  AsyncQueue<SwiftThreadFunc>
        ) {

        self.tcpListener     = tcpListener
        self.parser          = parser
        self.serializer      = serializer
        self.middleware      = middleware
        self.responder       = responder
        self.errorCallBack   = errorCallBack
        self.eventNotifier   = eventNotifier
        self.threadPoolQueue = threadPoolQueue
        self.processors = [Int32:HttpProcessor]()
    }

    func serve() throws {
        print("process SingleSocket")
        while(true){
            if eventNotifier.isWaiting() {
                try eventNotifier.wait { socket in
                    self.doAcceptOrRead(socket: socket)
                }
            }
        }
    }

    private func doAcceptOrRead(socket: Int32){

        do {
            if ( socket == self.tcpListener.getSocket() ){
                try accept()
            } else {
                var p = self.processors[socket]

                if p == nil {
                    let client = TcpClient(socketfd: socket)
                    p = HttpProcessor(httpServer: self, client: client, middleware: self.middleware,callBack: self.responder)
                    self.processors[socket] = p
                }

                try readAndResponse(processor: p!)
            }
        } catch {
            print("exception occured") // TODO
        }
    }
    
    private func accept() throws {
        let client = self.tcpListener.tcpAccept()
        print("accept and event add")
        try self.eventNotifier.add(handler: client)
    }
    
    private func readAndResponse(processor: HttpProcessor) throws {
        
        try self.eventNotifier.disable(handler: processor.client)
        try self.threadPoolQueue.put {
            print("client thread read")
            do {
                try processor.doProcessLoop(mutex: self.mutex)
                if processor.client.closed {
                    self.processors[processor.client.getSocket()] = nil
                } else {
                    try self.eventNotifier.enable(handler: processor.client)
                }
            } catch NotifyError.errno(let errno) {
                print("exception in thread1 : \(errno)") //TODO
            } catch {
                print("exception in thread1") //TODO
                
            }
        }
    }
    
//    func serve() throws {
//        while(true){
//            let client = self.tcpListener.tcpAccept()
//
//            _ = try Thread.new(detachState: ThreadUnit.DetachState.detached) {
//                do {
//                    let processor = HttpProcessor(httpServer: self, client: client, middleware: self.middleware,callBack: self.responder)
//                    
//                    try processor.doProcessLoop(mutex: self.mutex)
//                    
//                } catch {
//                    print("error")
//                }
//            }
//        }
//    }

    func use(add_middleware: Middleware){
        middleware.append(add_middleware)
    }
    
    
    class HttpProcessor {
        let httpServer: HttpServer
        let middleware: [Middleware]
        let callBack:   Responder
        let client:     TcpClient
        let stream:     TcpStream

        init(httpServer: HttpServer, client: TcpClient, middleware: [Middleware], callBack: Responder) {
            self.httpServer = httpServer
            self.middleware = middleware
            self.callBack   = callBack
            self.client     = client
            self.stream     = TcpStream(client: client)
            print("HttpProcessor init")
        }
        
        deinit {
            print("HttpProcessor deinit")
        }
        
        func doProcessLoop(mutex: PosixMutex) throws {
            let readBuffer = self.httpServer.parser.createReadBuffer();
            
            guard let data = try self.client.tcpRead() else {
                try self.client.tcpClose()
                print("tcp close")
                return
            }
            
            print("lenbytes = \(data.lenBytes)")
            
            guard data.lenBytes != 0 else {
                try self.client.tcpClose()
                print("tcp close2")
                return
            }
            
            if let str = data.description  {
                print(str)
            }

            self.httpServer.parser.parse(readBuffer: readBuffer, readData: data) { [unowned self] request in
                    let response = try self.middleware.chain(to: self.callBack).respond(to: request)
                    self.serialize(response: response)
                
                    if let didUpgrade = response.didUpgrade {
                        try didUpgrade(request, self.stream)
                        print("close client")
                        try self.client.tcpClose()
                    }
            }
        }
        
        private func errorRespond(error: ErrorProtocol){
            if let response = self.httpServer.errorCallBack(error: error) {
                self.serialize(response: response)
            }
        }

        private func serialize(response: Response){
            do {
                try self.httpServer.serializer.serialize(response: response, stream: self.stream)
            } catch {
                assert(false, "This code path is expected to be not called.")
            }
        }
    }

}
