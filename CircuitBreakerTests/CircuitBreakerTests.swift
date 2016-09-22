import XCTest
@testable import CircuitBreaker

class CircuitBreakerTests: XCTestCase {
    
    fileprivate var testService: TestService!
    fileprivate var circuitBreaker: CircuitBreaker!
    
    override func setUp() {
        super.setUp()
        
        testService = TestService()
    }
    
    override func tearDown() {
        circuitBreaker.reset()
        circuitBreaker.didTrip = nil
        circuitBreaker.call = nil
        
        super.tearDown()
    }
    
    func testSuccess() {
        let expectation = self.expectation(description: "Successful call")
        
        circuitBreaker = CircuitBreaker()
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.successCall { data, error in
                XCTAssertNotNil(data)
                XCTAssertNil(error)
                circuitBreaker.success()
                expectation.fulfill()
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 10) { _ in }
    }
    
    func testTimeout() {
        let expectation = self.expectation(description: "Timed out call")
        
        circuitBreaker = CircuitBreaker(timeout: 3.0)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.delayedCall(5) { _ in }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    expectation.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 15) { _ in }
    }
    
    func testFailure() {
        let expectation = self.expectation(description: "Failure call")
        
        circuitBreaker = CircuitBreaker(timeout: 10.0, maxRetries: 1)
        circuitBreaker.call = { [weak self] circuitBreaker in
            switch circuitBreaker.failureCount {
            case 0:
                self?.testService?.failureCall { data, error in
                    XCTAssertNil(data)
                    XCTAssertNotNil(error)
                    circuitBreaker.failure()
                }
            default:
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    expectation.fulfill()
                }
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 10) { _ in }
    }
    
    func testTripping() {
        let expectation = self.expectation(description: "Tripped call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 2,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        
        circuitBreaker.didTrip = { circuitBreaker, error in
            XCTAssertTrue(circuitBreaker.state == .open)
            XCTAssertTrue(circuitBreaker.failureCount == circuitBreaker.maxRetries + 1)
            XCTAssertTrue((error as! NSError).code == 404)
            circuitBreaker.reset()
            expectation.fulfill()
        }
        circuitBreaker.call = { [weak self] circuitBreaker in
            self?.testService.failureCall { data, error in
                circuitBreaker.failure(NSError(domain: "TestService", code: 404, userInfo: nil))
            }
        }
        circuitBreaker.execute()
        
        waitForExpectations(timeout: 100) { error in
            print(error)
        }
    }
    
    func testReset() {
        let expectation = self.expectation(description: "Reset call")
        
        circuitBreaker = CircuitBreaker(
            timeout: 10.0,
            maxRetries: 1,
            timeBetweenRetries: 1.0,
            exponentialBackoff: false,
            resetTimeout: 2.0
        )
        circuitBreaker.call = { [weak self] circuitBreaker in
            if circuitBreaker.state == .halfOpen {
                self?.testService?.successCall { data, error in
                    circuitBreaker.success()
                    XCTAssertTrue(circuitBreaker.state == .closed)
                    expectation.fulfill()
                }
                return
            }
            
            self?.testService.failureCall { data, error in
                circuitBreaker.failure()
            }
        }
        circuitBreaker.execute()
        
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(4.0 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)) {
            self.circuitBreaker.execute()
        }
        
        waitForExpectations(timeout: 10) { _ in }
    }
    
}


