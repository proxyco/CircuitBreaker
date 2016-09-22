import Foundation

open class TestService {
    
    public typealias CompletionBlock = (Data?, Error?) -> Void
    
    open func successCall(_ completion: @escaping CompletionBlock) {
        makeCall("get", completion: completion)
    }
    
    open func failureCall(_ completion: @escaping CompletionBlock) {
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            completion(nil, NSError(domain: "TestService", code: 404, userInfo: nil))
        }
    }
    
    open func delayedCall(_ delayInSeconds: Int, completion: @escaping CompletionBlock) {
        makeCall("delay/\(delayInSeconds)", completion: completion)
    }
    
    fileprivate func makeCall(_ path: String, completion: @escaping CompletionBlock) {
        let task = URLSession.shared.dataTask(with: URL(string: "https://httpbin.org/\(path)")!, completionHandler: { data, response, error in
            DispatchQueue.main.async {
                completion(data, error)
            }
        }) 
        task.resume()
    }
    
}
