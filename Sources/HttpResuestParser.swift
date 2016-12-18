import HTTPParser

typealias ParsedCallBack = (request: Request) throws -> Void

protocol HttpRequestParsable {
    func parse(readBuffer: ReadBuffer, readData: Data ,callBack: ParsedCallBack)
    func createReadBuffer() -> ReadBuffer
}

class HttpRequestParser : HttpRequestParsable {
    func createReadBuffer() -> ReadBuffer {
        return ReadBuffer()
    }
    
    func parse(readBuffer: ReadBuffer, readData: Data ,callBack: ParsedCallBack) {
        readBuffer.append(newData: readData)
        
        
        let parser = RequestParser()
        
        do {
            if let request = try parser.parse(readBuffer.bufferData) {
                
                readBuffer.initialize()
                
                try callBack(request: request)
            }
        }catch(let error){
            print("error",error)
        }
        
    }
}

class ReadBuffer {
    var bufferData = Data()
    
    var data:Data {
        get {
            return bufferData
        }
    }
    
    func initialize(){
        
        bufferData = Data()
        
    }
    
    func append(newData: Data){
        
        //            let b = bufferData.bytes
        //            b += newData.data.bytes
        bufferData = Data(bufferData.bytes + newData.bytes)
        
    }
    
    func toData() -> Data {
        
        return bufferData
    }
}
