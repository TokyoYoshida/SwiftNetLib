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

class HttpServer : HttpServable {
    private let tcpListener:     ServerType
    private let parser:          HttpRequestParsable
    private let serializer:      HTTPResponseSerializable
    private let errorCallBack:   ErrorCallBack
    private var middleware:      [Middleware]
    private let responder:       Responder
    private let eventNotifier:   EventNotifier
    private let threadPoolQueue: AsyncQueueType<SwiftThreadFunc>
    private let procKeeper     = ProcessorKeeper()
    
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
        while(true){
            try eventNotifier.wait { socket in
                try self.eventNotifier.clear(socket: socket)
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

        let p = HttpProcessor(httpServer: self, stream: client, middleware: self.middleware,callBack: self.responder)
        if self.procKeeper.get(socket: client.getSocket()) != nil {
            assert(false, "same processor is exist socket = <\(client.getSocket())>")
        }
        
        self.procKeeper.add(socket: client.getSocket(), processor: p)
        try self.eventNotifier.add(socket: client.getSocket())
        try self.eventNotifier.enable(socket: client.getSocket())
    }
    
    private func readAndResponse(processor: HttpProcessor) throws {
        try self.threadPoolQueue.put {
            do {
                let keepThis = try processor.doProcessLoop()
                if !keepThis {
                    try! self.deleteAndclose(target: processor)
                } else {
                    try self.eventNotifier.enable(socket: processor.stream.getSocket())
                }
            } catch NotifyError.errno(let errno) {
                print("exception in thread1 : \(errno)") //TODO
            } catch StreamError.closedStream(_) {
                try! self.deleteAndclose(target: processor)
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
    
    func deleteAndclose(target: HttpProcessor) throws {
        procKeeper.delete(socket: target.stream.getSocket())
        try target.stream.close()
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
        }
        
        
        func doProcessLoop() throws -> Bool {
            var keepThis  = true
            let data = try self.stream.receive(upTo:TcpData.DEFAULT_BUFFER_SIZE)
            
            
            guard data.bytes.count != 0 else {
                return false
            }
            

            self.httpServer.parser.parse(readBuffer: self.readBuffer, readData: data) { [unowned self] request in
                let response = try self.middleware.chain(to: self.callBack).respond(to: request)
                guard self.serialize(response: response) == true else {
                    keepThis = false
                    return
                }
                
                if let didUpgrade = response.didUpgrade {
                    try didUpgrade(request, self.stream)
                    keepThis = false
                }
                
                if !request.isKeepAlive {
                    keepThis = false
                }
                
            }
            return keepThis
        }
        
        private func errorRespond(error: ErrorProtocol){
            if let response = self.httpServer.errorCallBack(error: error) {
                self.serialize(response: response)
            }
        }

        private func serialize(response: Response) -> Bool {
            do {
                try self.httpServer.serializer.serialize(response: response, stream: self.stream)
                return true
            } catch (let error ){
                print("serialize error. \(error.dynamicType)") // TODO
                return false
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
