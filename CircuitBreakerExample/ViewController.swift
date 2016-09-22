import UIKit
import CircuitBreaker

class ViewController: UIViewController {
    
    @IBOutlet weak var infoTextView: UITextView!
    
    fileprivate let testService = TestService()
    fileprivate var circuitBreaker: CircuitBreaker?
    fileprivate var callShouldSucceed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 2,
            timeBetweenRetries: 2.0,
            exponentialBackoff: true,
            resetTimeout: 2.0
        )
        circuitBreaker?.didTrip = { [weak self] circuitBreaker, error in
            self?.logInfo("Failure (Code: \((error as! NSError).code)). Tripped! State: \(circuitBreaker.state)")
        }
        circuitBreaker?.call = { [weak self] circuitBreaker in
            guard let strongSelf = self else { return }
            strongSelf.logInfo("Perform call. State: \(circuitBreaker.state), failureCount: \(circuitBreaker.failureCount)")
            
            if strongSelf.callShouldSucceed {
                strongSelf.testService.successCall() { data, error in
                    circuitBreaker.success()
                    strongSelf.logInfo("Success. State: \(circuitBreaker.state)")
                }
            } else {
                strongSelf.testService.failureCall() { data, error in
                    if circuitBreaker.failureCount < circuitBreaker.maxRetries {
                        strongSelf.logInfo("Failure. Will retry. State: \(circuitBreaker.state)")
                    }
                    circuitBreaker.failure(error)
                }
            }
        }
    }
    
    @IBAction func didTapFailureCall(_ sender: AnyObject) {
        logInfo("> Start Failure Call")
        callShouldSucceed = false
        circuitBreaker?.execute()
    }
    
    @IBAction func didTapSuccessCall(_ sender: AnyObject) {
        logInfo("> Start Success Call")
        callShouldSucceed = true
        circuitBreaker?.execute()
    }
    
    fileprivate func logInfo(_ info: String) {
        var newInfo = infoTextView.text
        newInfo.append("\(info)\n")
        infoTextView.text = newInfo
    }
    
}
