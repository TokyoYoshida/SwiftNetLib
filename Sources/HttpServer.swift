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
    private let procKeeper     = ProcessorKeeper()
    private let mutex          = PosixMutex()
    
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
            let n = sync{
                busy.reduce(0) { (a,h) in
                    a + h.value
                }
            }
            
            print("waiting..\(n)")
            try eventNotifier.wait { socket in
                try self.eventNotifier.clear(socket: socket)
                print("starting..\(n)")
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
                    print("socket already closed. socket = <\(socket)>")
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
        try sync(mutex: mutex) {
        let client = try self.tcpListener.accept()
        print("accept socket = <\(client.getSocket())>")

//        let fl = fcntl(client.getSocket(), F_GETFL)
//        fcntl(client.getSocket(), fl|O_NONBLOCK)
//        
        let p = HttpProcessor(httpServer: self, stream: client, middleware: self.middleware,callBack: self.responder)
        if let op = self.procKeeper.get(socket: client.getSocket()) {
            print("same processor is exist socket = <\(client.getSocket())>")
            op.isZombie = true
        }
        
        self.procKeeper.add(socket: client.getSocket(), processor: p)
        try self.eventNotifier.add(socket: client.getSocket())
        try self.eventNotifier.enable(socket: client.getSocket())
        }
    }
    
    private func readAndResponse(processor: HttpProcessor) throws {
        try self.threadPoolQueue.put {
            do {
                try processor.doProcessLoop()
                try sync(mutex: self.mutex) {
                    if processor.stream.closed && !processor.isZombie {
                        print("stream closed by self. socket = <\(processor.stream.getSocket())> \(#file) \(#line)")
                        self.procKeeper.delete(socket: processor.stream.getSocket())
                    } else {
                        try self.eventNotifier.enable(socket: processor.stream.getSocket())
                    }
                }
            } catch NotifyError.errno(let errno) {
                print("exception in thread1 : \(errno)") //TODO
            } catch StreamError.closedStream(_) {
                print("stream closed by peer. socket = <\(processor.stream.getSocket())> \(#file) \(#line)")
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
        var isZombie  = false

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
            print("doProcess start socket = <\(self.stream.getSocket())>")
//            print("sleep start")
//            sleep(10)
//            print("sleep end")
//            
            if(isZombie){
                return
            }
            let data = try self.stream.receive(upTo:TcpData.DEFAULT_BUFFER_SIZE)
            
            print("lenbytes = \(data.bytes.count)")
            
            guard data.bytes.count != 0 else {
                print("close stream 1 socket = <\(self.stream.getSocket())>")
                try self.stream.close()
                return
            }
            
//            if let str:String = data.description  {
//                print(str)
//            }

            self.httpServer.parser.parse(readBuffer: self.readBuffer, readData: data) { [unowned self] request in
                let response = try self.middleware.chain(to: self.callBack).respond(to: request)
                    print("return response")
                    if(self.isZombie){
                        return
                    }
                    self.serialize(response: response)
                
                    if let didUpgrade = response.didUpgrade {
                        try didUpgrade(request, self.stream)
                        print("close stream 2 socket = <\(self.stream.getSocket())>")
                        try self.stream.close()
                    }
                
                if !request.isKeepAlive {
                    print("close stream 3 socket = <\(self.stream.getSocket())>")
                    try self.stream.close()
                }
                
            }
        }
        
        private func errorRespond(error: ErrorProtocol){
            print("error respond")
            if let response = self.httpServer.errorCallBack(error: error) {
                self.serialize(response: response)
            }
        }

        private func serialize(response: Response){
            do {
                try self.httpServer.serializer.serialize(response: response, stream: self.stream)
            } catch (let error ){
                print("serialize error. \(error.dynamicType)") // TODO
                print("close stream 4 socket = <\(self.stream.getSocket())>")
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
