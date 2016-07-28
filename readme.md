## SwiftLibuv

SwiftNetLib is TCP network library, in multi-thread support.
It also provides a simple framework of Web applications that use these libraries.

## Build exsample application

There is a sample of the Web server.

To build, run the following command.
```
swift build
```

## Execution exsample application

### Web Server
```
.build/debug/SwiftNetLib httpServer
```
And access from your browser to http://localhost:5188/

## Using Web Framework

For example.
```
let server =     HttpServer(
    tcpListener: tcpServer,
    errorCallBack: errorCallBack )

try server.serve { request in
        return Response(body: Data("this is test"))
}
```

## contribution

Contribution is welcome!

If there is contact, please write to the Issues. Or, please mail.
yoshidaforpublic@gmail.com

## License

 MIT
