#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func client() -> Int32
{
    print("client mode")

    var socketfd: Int32
    var ret:      Int32
	
	socketfd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
	if (socketfd < 0) {
        print("error1")
    }

	var serveraddr = sockaddr_in()
	serveraddr.sin_family = UInt8(AF_INET)
    serveraddr.sin_port = UInt16(bigEndian: 5188)
	serveraddr.sin_addr.s_addr = inet_addr("127.0.0.1");
    let serverPointer:UnsafePointer<sockaddr> = withUnsafePointer(&serveraddr) { UnsafePointer($0) }

    ret = connect(socketfd, serverPointer, UInt32(sizeofValue(serveraddr)))
	if (ret < 0) {
        print("error2")
	}

    var sendbuf:[CChar] = [CChar](repeating: 0, count: 1024)
    var recvbuf:[CChar] = [CChar](repeating: 0, count: 1024)
    
    while fgets(UnsafeMutablePointer(sendbuf), Int32(sendbuf.count * sizeofValue(sendbuf[0])), stdin) != nil {
        write(socketfd, UnsafeMutablePointer(sendbuf), Int(strlen(UnsafeMutablePointer(sendbuf))))
		read(socketfd, UnsafeMutablePointer(recvbuf), recvbuf.count * sizeofValue(recvbuf[0]))
		fputs(UnsafeMutablePointer(recvbuf), stdout)
		memset(UnsafeMutablePointer(sendbuf), 0, sendbuf.count * sizeofValue(sendbuf[0]))
		memset(UnsafeMutablePointer(recvbuf), 0, recvbuf.count * sizeofValue(recvbuf[0]))
	}
    

	close(socketfd)

	return 0
}
