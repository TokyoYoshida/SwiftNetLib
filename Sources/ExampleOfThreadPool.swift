#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func threadPool() -> Int32
{






    let queue = AsyncQueue<SwiftThreadFunc>(size:10)
    let consumer = ThreadPoolConsumer(queue: queue)
    try! consumer.makePoolThreads(numOfThreads:7)
    
    var ar = Array(repeating: 0, count: 30)
    [Int](0..<30).forEach { n in
        try! queue.put { _ in
            sleep(arc4random_uniform(3))
            ar[n] = 1
            _ = print("thread ar: \(ar) , queue number : \(n)" )
        }
        print("queue \(n) is putted.")
    }
    
    queue.close()
    try! consumer.joinAllPoolThreads()
    
    return 0
}
