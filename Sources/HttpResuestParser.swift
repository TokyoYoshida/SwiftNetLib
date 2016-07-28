import HTTPParser

typealias ParsedCallBack = (request: Request) -> Void

protocol HttpRequestParsable {
    func parse(readData: DataType ,callBack: ParsedCallBack)
}

class HttpRequestParser : HttpRequestParsable {
    private var readBuffer = ReadBuffer()
    
    init() {
        readBuffer.initialize()
    }
    
    func parse(readData: DataType ,callBack: ParsedCallBack) {
        readBuffer.append(newData: readData)
        
        
        let parser = RequestParser()
        
        print("data = <\(readBuffer.toData().description)>")
        do {
            if let request = try parser.parse(readBuffer.toData()) {
                
                readBuffer.initialize()
                
                callBack(request: request)
            }
        }catch(let error){
            print("error",error)
        }
        
    }

    private class ReadBuffer {
        var bufferData = Data()

        var data:Data {
            get {
                return bufferData
            }
        }
        
        func initialize(){
            
            bufferData = Data()
            
        }
        
        func append(newData: DataType){
            
//            let b = bufferData.bytes
//            b += newData.data.bytes
            bufferData = Data(bufferData.bytes + newData.data.bytes)
            
        }
        
        func toData() -> Data {
            
            return bufferData
        }
    }
}
