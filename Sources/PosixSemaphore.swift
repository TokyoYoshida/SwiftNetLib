#if os(OSX)
    import Darwin
#elseif os(Linux)
    import Glibc
#endif

extension String {
    
    static func randomStringWithLength(length: Int, allowedCharacters: Set<Character>) -> String {
        let outputRange = (0..<length)
        let characterPalette = Array(allowedCharacters)
        
        return outputRange.reduce("") { (string, _) -> String in
            let randomValueUpperBound = UInt32(characterPalette.count)
            let randomValue = arc4random_uniform(randomValueUpperBound)
            let characterIndex = Int(randomValue)
            let character = characterPalette[characterIndex]
            
            return string + String(character)
        }
    }
    
    static func randomAlphabetNumberStringWithLength(length: Int) -> String {
        let alphabet:Set<Character> = ["1","2","3","4","5","6","7","8","9","0","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"]
        
        return String.randomStringWithLength(length: length, allowedCharacters: alphabet)
    }
    
}

public class PosixSemaphore  {
    private var semaphoreName: String
    private var handle:        UnsafeMutablePointer<sem_t>!
    
    public enum Error: ErrorProtocol {
        case errno(errorNo: Int32)
    }
    
    init(semaphoreName: String = "/sem\(String.randomAlphabetNumberStringWithLength(length: 20))", initialValue: UInt32 = 0) throws {
        
        self.semaphoreName = semaphoreName
        try unlink()
        
        try open(initialValue: initialValue)
    }
    
    
    public func wait() throws {
        guard sem_wait(handle) != -1 else {
            throw Error.errno(errorNo: errno)
        }
    }
    
    public func post() throws {
        guard sem_post(handle) != -1 else {
            throw Error.errno(errorNo: errno)
        }
    }
    
    
    public func finalize() throws {
        try unlink()
        try close()
    }
    
    deinit {
        do {
            try finalize()
        } catch {
            assert(false, "This block is expected to be not called.")
        }
    }
    
    private func open(initialValue: UInt32) throws {
        handle = sem_open(self.semaphoreName, O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP|S_IROTH, initialValue)
        
        guard handle != SEM_FAILED else {
            throw Error.errno(errorNo: errno)
        }
    }
    
    private func unlink() throws {
        try _ = semaphoreName.withCString {
            guard sem_unlink($0) != -1 else {
                throw Error.errno(errorNo: errno)
            }
        }
    }
    
    private func close() throws {
        guard sem_close(handle) != -1 else {
            throw Error.errno(errorNo: errno)
        }
    }
}
