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
    private var middleware:      [Middleware]
    private let responder:       Responder
    private let eventNotifier:   EventNotifier
    private let threadPoolQueue: AsyncQueueType<SwiftThreadFunc>
    private let procKeeper = ProcessorKeeper()
    
    init(tcpListener:   ServerType,
         parser:        HttpRequestParsable = HttpRequestParser(),
         serializer:    HTTPResponseSerializable = HTTPResponseSerializer(),
         middleware:    [Middleware] = [],
         errorCallBack: ErrorCallBack,
         responder:     Responder,
         eventNotifier:  EventNotifier,
         threadPoolQueue:  AsyncQueueType<SwiftThreadFunc>
        ) {
        self.tcpListener     = tcpListener
        self.parser          = parser
        self.serializer      = serializer
        self.middleware      = middleware
        self.responder       = responder
        self.errorCallBack   = errorCallBack
        self.eventNotifier   = eventNotifier
        self.threadPoolQueue = threadPoolQueue
    }

    func serve() throws {
        print("process SingleSocket")
        while(true){
            print("waiting..")
            try eventNotifier.wait { socket in
//                try self.eventNotifier.disable(socket: socket)
                self.doAcceptOrRead(socket: socket)
            }
        }
    }

    private func doAcceptOrRead(socket: Int32){
        do {
            if ( socket == self.tcpListener.getSocket() ){
                try accept()
            } else {
                try self.eventNotifier.disable(socket: socket)
                guard let p = procKeeper.get(socket: socket) else {
                    print("socket already closed.")
                    procKeeper.delete(socket: socket)
                    return
                }

                try readAndResponse(processor: p)
            }
        } catch {
            print("exception occured") // TODO
        }
    }
    
    private func accept() throws {
        let client = try self.tcpListener.accept()
        print("accept and event add")
        let p = HttpProcessor(httpServer: self, stream: client, middleware: self.middleware,callBack: self.responder)
        procKeeper.add(socket: client.getSocket(), processor: p)
        try self.eventNotifier.add(socket: client.getSocket())
    }
    
    private func readAndResponse(processor: HttpProcessor) throws {
        try self.threadPoolQueue.put {
            do {
                try processor.doProcessLoop()
                if processor.stream.closed {
                    self.procKeeper.delete(socket: processor.stream.getSocket())
                } else {
                    try self.eventNotifier.enable(socket: processor.stream.getSocket())
                }
            } catch NotifyError.errno(let errno) {
                print("exception in thread1 : \(errno)") //TODO
            } catch StreamError.closedStream(_) {
                self.procKeeper.delete(socket: processor.stream.getSocket())
            } catch (Error.errno(let errno) ){
                print("exception in thread1. errno = \(errno)") //TODO
            } catch (let err){
                print("exception in thread1. errtype = \(err.dynamicType)") //TODO
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
        let readBuffer: ReadBuffer
        

        init(httpServer: HttpServer, stream: HandledStream, middleware: [Middleware], callBack: Responder) {
            self.httpServer = httpServer
            self.middleware = middleware
            self.callBack   = callBack
            self.stream     = stream
            self.readBuffer = httpServer.parser.createReadBuffer();
            print("HttpProcessor init")
        }
        
        deinit {
            print("HttpProcessor deinit")
        }
        
        func doProcessLoop() throws {
            let data = try self.stream.receive(upTo:TcpData.DEFAULT_BUFFER_SIZE)
            
            print("lenbytes = \(data.bytes.count)")
            
            guard data.bytes.count != 0 else {
                try self.stream.close()
                print("tcp close2")
                return
            }
            
//            if let str:String = data.description  {
//                print(str)
//            }

            self.httpServer.parser.parse(readBuffer: self.readBuffer, readData: data) { [unowned self] request in
                let response = try self.middleware.chain(to: self.callBack).respond(to: request)
                    self.serialize(response: response)
                
                    if let didUpgrade = response.didUpgrade {
                        try didUpgrade(request, self.stream)
                        print("close strem")
                        try self.stream.close()
                    }
                
                if !request.isKeepAlive {
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
                print("serialize error.") // TODO
            }
        }
    }
    
    class ProcessorKeeper {
        private let mutex = PosixMutex()
        var processors = [Int32:HttpProcessor]()
        
        func add(socket: Int32, processor: HttpProcessor){
            sync(mutex: mutex){
                self.processors[socket] = processor
            }
        }
        
        func delete(socket: Int32){
            sync(mutex: mutex){
                self.processors[socket] = nil
            }
        }

        func get(socket: Int32) -> HttpProcessor? {
            return sync(mutex: mutex){
                return self.processors[socket]
            }
        }
    }
}
