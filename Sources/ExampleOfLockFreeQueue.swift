#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

func lockFreeQueue() -> Int32
{
    

    let q = LockFreeAsyncQueue<Int>()





    do {
        try q.put(obj: 1)
        try q.put(obj: 2)
        let v = try q.get()
        print("value = \(v)")
        let v2 = try q.get()
        print("value = \(v2)")
    } catch {
        print("error file : \(#file) line : \(#line)")
    }
    
    // Example with Thread
    var threads = [ThreadUnit]()
    for i in 0...100 {
        let t1 = try! Thread.new {
            print("this is thread1.")
            do {
                print("now put : \(i)")
                print(try q.get())
            } catch {
                print("error in thread 1")
            }
        }
        threads.append(t1)

        let t2 = try! Thread.new {
            print("this is thread2.")
            do {
                try q.put(obj:i)
            } catch {
                print("error in thread 2")
            }
        }
        threads.append(t2)
    }
    threads.forEach { try! $0.join() }
    q.close()

    return 0
}
