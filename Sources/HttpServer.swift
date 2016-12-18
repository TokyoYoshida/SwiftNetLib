import C7
import S4
import HTTPParser
import Foundation

public protocol HttpServable {
    func serve() throws
}

public protocol HandledHost{
    func accept() throws -> HandledStream
}

public protocol ServerType : SocketHandler,HandledHost {}

public protocol HandledStream : Stream,SocketHandler {}

typealias ErrorCallBack = (error: ErrorProtocol) -> Response?

// typealias Responder = (request: Request) -> Response?

class HttpServer : HttpServable {
    private let tcpListener:     ServerType
    private let parser:          HttpRequestParsable
    private let serializer:      HTTPResponseSerializable
    private let errorCallBack:   ErrorCallBack
    private let mutex =          PosixMutex()
    private var middleware:      [Middleware]
    private let responder:       Responder
    private let eventNotifier:   EventNotifier
    private let threadPoolQueue: AsyncQueue<SwiftThreadFunc>
    private var processors:      [Int32:HttpProcessor]
    
    init(tcpListener:   ServerType,
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
            eventNotifier.blockUntilIntoWaitingState()
            try eventNotifier.wait { socket in
                self.doAcceptOrRead(socket: socket)
            }
        }
    }

    private func doAcceptOrRead(socket: Int32){

        do {
            if ( socket == self.tcpListener.getSocket() ){
                try accept()
            } else {
                let p = self.processors[socket]

                guard p != nil else {
                    assert(false, "This block is expected to be not called.")
                }

                try readAndResponse(processor: p!)
            }
        } catch {
            print("exception occured") // TODO
        }
    }
    
    private func accept() throws {
        let client = try self.tcpListener.accept()
        print("accept and event add")
        let p = HttpProcessor(httpServer: self, stream: client, middleware: self.middleware,callBack: self.responder)
        self.processors[client.getSocket()] = p
        try self.eventNotifier.add(handler: client)
    }
    
    private func readAndResponse(processor: HttpProcessor) throws {
        
        try self.eventNotifier.disable(handler: processor.stream)
        try self.threadPoolQueue.put {
            print("client thread read")
            do {
                try processor.doProcessLoop(mutex: self.mutex)
                if processor.stream.closed {
                    self.processors[processor.stream.getSocket()] = nil
                } else {
                    try self.eventNotifier.enable(handler: processor.stream)
                }
            } catch NotifyError.errno(let errno) {
                print("exception in thread1 : \(errno)") //TODO
            } catch {
                print("exception in thread1") //TODO
                
            }
        }
    }

    func use(add_middleware: Middleware){
        middleware.append(add_middleware)
    }
    
    class HttpProcessor {
        let httpServer: HttpServer
        let middleware: [Middleware]
        let callBack:   Responder
        let stream:     HandledStream

        init(httpServer: HttpServer, stream: HandledStream, middleware: [Middleware], callBack: Responder) {
            self.httpServer = httpServer
            self.middleware = middleware
            self.callBack   = callBack
            self.stream     = stream
            print("HttpProcessor init")
        }
        
        deinit {
            print("HttpProcessor deinit")
        }
        
        func doProcessLoop(mutex: PosixMutex) throws {
            let readBuffer = self.httpServer.parser.createReadBuffer();
            
            guard let recvData:Data? = try self.stream.receive(upTo:TcpData.DEFAULT_BUFFER_SIZE) else {
                try self.stream.close()
                print("tcp close")
                return
            }
            
            guard let data = recvData else {
                try self.stream.close()
                print("tcp close")
                return
            }
            
            print("lenbytes = \(data.bytes.count)")
            
            guard data.bytes.count != 0 else {
                try self.stream.close()
                print("tcp close2")
                return
            }
            
            if let str:String = data.description  {
                print(str)
            }

            self.httpServer.parser.parse(readBuffer: readBuffer, readData: data) { [unowned self] request in
                    let response = try self.middleware.chain(to: self.callBack).respond(to: request)
                    self.serialize(response: response)
                
                    if let didUpgrade = response.didUpgrade {
                        try didUpgrade(request, self.stream)
                        print("close strem")
                        try self.stream.close()
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
