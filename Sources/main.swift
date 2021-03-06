print("now starting.")

var ret:Int32 = 0

var args = Process.arguments
args[1..<args.count].forEach {
    switch $0 {
    case "client":
        ret = client()
    case "server":
        ret = server()
    case "thread":
        ret = thread()
    case "threadLib":
        ret = threadLib()
    case "tcpLibClient":
        ret = tcpLibClient()
    case "tcpLibServer":
        ret = tcpLibServer()
    case "threadServerLib":
        ret = threadServerLib()
    case "httpServer":
        ret = httpServer()
    case "threadPool":
        ret = threadPool()
    case "kqueue":
        ret = kqueueLib()
    case "lockFreeQueue":
        ret = lockFreeQueue()
    default:
        print("error: Unknown command.")
    }
}

print("return value = \(ret)")

