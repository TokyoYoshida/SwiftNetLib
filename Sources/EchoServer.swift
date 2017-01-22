#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func server() -> Int32
{
    print("server mode")
    
    var listenfd: Int32
    var ret:      Int32
    
    listenfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
	if (listenfd < 0) {
        print("error1")
    }


	var serveraddr = sockaddr_in()
	memset(&serveraddr, 0, sizeofValue(serveraddr))
	serveraddr.sin_family = UInt8(AF_INET)
    serveraddr.sin_port = UInt16(bigEndian: 5188)
	serveraddr.sin_addr.s_addr = inet_addr("127.0.0.1")
    let serverPointer:UnsafePointer<sockaddr> = withUnsafePointer(&serveraddr) { UnsafePointer($0) }

	var on = 1
	ret = setsockopt(listenfd, SOL_SOCKET, SO_REUSEADDR, &on, UInt32(sizeofValue(on)))
    if (ret < 0) {
        print("error2")
    }
	ret = bind(listenfd, serverPointer, UInt32(sizeofValue(serveraddr)))
	if (ret < 0) {
        print("error3")
    }

	ret = listen(listenfd, SOMAXCONN)
	if (ret < 0) {
        print("error4")
	}

	var peeraddr = sockaddr_in()
    var peeraddr_len = socklen_t(sizeofValue(peeraddr))
    let peerPointer:UnsafeMutablePointer<sockaddr> = withUnsafePointer(&peeraddr) { UnsafeMutablePointer($0) }

    var connectfd:Int32
	connectfd = accept(listenfd, peerPointer, &peeraddr_len)
	if (connectfd < 0) {
        print("error5")
    }

	print("ip address: \(inet_ntoa(peeraddr.sin_addr)), port: \(peeraddr.sin_port)\n")

    var recbuf:[CChar] = [CChar](repeating: 0, count: 1024)

    var i = 0
    while(i < 10000) {
		memset(UnsafeMutablePointer(recbuf), 0, sizeofValue(recbuf[0]) * recbuf.count)
		let len = read(connectfd, UnsafeMutablePointer(recbuf), sizeofValue(recbuf[0]) * recbuf.count)
        if let str = String(validatingUTF8: recbuf) {
            print(str)
        }
		write(connectfd, recbuf, len)
        i += 1
	}

	close(listenfd)

	return 0
}
