class ThreadPoolConsumer {
    var queue: AsyncQueueType<SwiftThreadFunc>
    var threads = ThreadUnitContainer()
    
    init(queue: AsyncQueueType<SwiftThreadFunc>){
        self.queue = queue
    }
    
    func run(i: Int) {
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
        try [Int](0..<numOfThreads).forEach { i in
            try threads.add {
                self.run(i:i)
            }
        }
    }
    
    func joinAllPoolThreads() throws {
        try threads.joinAll()
    }
}
