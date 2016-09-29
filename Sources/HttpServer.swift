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
    private let tcpListener:   TcpServer
    private let parser:        HttpRequestParsable
    private let serializer:    HTTPResponseSerializable
    private let errorCallBack: ErrorCallBack
    private let mutex =        PosixMutex()
    private var middleware:    [Middleware]
    private let responder:     Responder
    
    init(tcpListener:   TcpServer,
         parser:        HttpRequestParsable = HttpRequestParser(),
         serializer:    HTTPResponseSerializable = HTTPResponseSerializer(),
         middleware:    [Middleware] = [],
         errorCallBack: ErrorCallBack,
         responder:     Responder ) {

        self.tcpListener   = tcpListener
        self.parser        = parser
        self.serializer    = serializer
        self.middleware    = middleware
        self.responder     = responder
        self.errorCallBack = errorCallBack
    }

    func serve() throws {
        while(true){
            let client = self.tcpListener.tcpAccept()
            
            _ = try Thread.new(detachState: ThreadUnit.DetachState.detached) {
                do {
                    let processor = HttpProcessor(httpServer: self, client: client, middleware: self.middleware,callBack: self.responder)
                    
                    try processor.doProcessLoop(mutex: self.mutex)

                } catch {
                    print("error")
                }
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
            
            while(!self.client.closed){
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
                            try self.client.tcpClose()
                        }
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
