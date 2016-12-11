
class ThreadPoolConsumer {
    var queue: AsyncQueue<SwiftThreadFunc>
    var threads = ThreadUnitContainer()
    
    init(queue: AsyncQueue<SwiftThreadFunc>){
        self.queue = queue
    }
    
    func run() {
        while(true){
            guard let queueFunc = try? queue.get() else {
                break
            }
            guard let threadFunc = queueFunc else {
                break
                // TODO : This block passes when queue throws an exception. Therefore we need to add exception handling.
            }
            threadFunc()
        }
    }

    func makePoolThreads(numOfThreads: Int) throws {
        try [Int](0..<numOfThreads).forEach { _ in
            try threads.add {
                self.run()
            }
        }
    }
    
    func joinAllPoolThreads() throws {
        try threads.joinAll()
    }
}
