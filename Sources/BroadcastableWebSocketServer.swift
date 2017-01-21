@_exported import WebSocket
@_exported import HTTP

public class WebSocketContainer {
    public var all = [Int:WebSocket]()
    private var key = 0
    private let mutex = PosixMutex()
    
    public func add(_ websocket: WebSocket) -> Int{
        return sync(mutex: mutex) { [unowned self] in
            let r = self.key

            self.all[self.key] = websocket

            self.key += 1

            return r
        }
    }

    public func delete(_ delKey: Int){
        return sync(mutex: mutex) {
            self.all[delKey] = nil
        }
    }
}

public class BroadcastableWebSocketServer: Responder, Middleware {
    private let didConnect: (Request, WebSocket, WebSocketContainer) throws -> Void
    private let webSockets = WebSocketContainer()
    
    public init(_ didConnect: (Request, WebSocket, WebSocketContainer) throws -> Void) {
        self.didConnect = didConnect
    }
    
    public func respond(to request: Request, chainingTo next: Responder) throws -> Response {
        guard request.isWebSocket && request.webSocketVersion == "13", let key = request.webSocketKey else {
            return try next.respond(to: request)
        }
        
        guard let accept = WebSocket.accept(key) else {
            return Response(status: .internalServerError)
        }
        
        let headers: Headers = [
            "Connection": "Upgrade",
            "Upgrade": "websocket",
            "Sec-WebSocket-Accept": Header([accept])
        ]
        
        let response = Response(status: .switchingProtocols, headers: headers) { request, stream in
            let webSocket = WebSocket(stream: stream, mode: .server)
            let delKey = self.webSockets.add(webSocket)
            webSocket.onClose {_,_ in
                    self.webSockets.delete(delKey)
            }
            
            print("websocket client plus : \(self.webSockets.all.count)")
            try self.didConnect(request, webSocket, self.webSockets)
            try webSocket.start()
        }

        print("websocket client num : \(webSockets.all.count)")
        
        return response
    }
    
    public func respond(to request: Request) throws -> Response {
        let badRequest = BasicResponder { _ in
            throw ClientError.badRequest
        }
        
        return try respond(to: request, chainingTo: badRequest)
    }
}
