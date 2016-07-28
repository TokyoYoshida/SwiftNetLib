import C7
import HTTPParser
import Foundation

protocol HttpServable {
    func serve(callBack: HttpListenCallBack) throws
}

typealias ErrorCallBack = (error: ErrorProtocol) -> Response?

typealias HttpListenCallBack = (request: Request) -> Response?

class HttpServer : HttpServable {
    private let tcpListener:   TcpServer
    private let parser:        HttpRequestParsable
    private let serializer:    HTTPResponseSerializable
    private let errorCallBack: ErrorCallBack
    private let mutex =            PosixMutex()
    
    init(tcpListener:   TcpServer,
         parser:        HttpRequestParsable = HttpRequestParser(),
         serializer:    HTTPResponseSerializable = HTTPResponseSerializer(),
         errorCallBack: ErrorCallBack) {

        self.tcpListener   = tcpListener
        self.parser        = parser
        self.serializer    = serializer
        self.errorCallBack = errorCallBack
    }

    func serve(callBack: HttpListenCallBack) throws {
        while(true){
            let client = self.tcpListener.tcpAccept()
            
            _ = try Thread.new(detachState: ThreadUnit.DetachState.detached) {
                do {
                    let processor = HttpProcessor(httpServer: self, client: client, callBack: callBack)
                    
                    try processor.doProcessLoop(mutex: self.mutex)

                } catch {
                    print("error")
                }
            }
        }
    }
    
    class HttpProcessor {
        let httpServer: HttpServer
        let callBack:   HttpListenCallBack
        let client:     TcpClient
        let stream:     TcpStream

        init(httpServer: HttpServer, client: TcpClient, callBack: HttpListenCallBack) {
            self.httpServer = httpServer
            self.callBack   = callBack
            self.client     = client
            self.stream     = TcpStream(client: client)
            print("HttpProcessor init")
        }
        
        deinit {
            print("HttpProcessor deinit")
        }
        
        func doProcessLoop(mutex: PosixMutex) throws {
            while(true){
                guard let data = try self.client.tcpRead() else {
                    try self.client.tcpClose()
                    print("tcp close")
                    return
                }
                
                if let str = data.description  {
                    print(str)
                }

                synchronized(mutex:mutex) {
                    self.httpServer.parser.parse(readData: data) { [unowned self] request in
                        if let response = self.callBack(request: request) {
                                self.serialize(response: response)
                        }
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
