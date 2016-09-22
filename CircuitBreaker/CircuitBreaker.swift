// MIT License: https://opensource.org/licenses/MIT
// Author: https://github.com/fe9lix/CircuitBreaker

import Foundation

open class CircuitBreaker {
    
    public enum State {
        case closed
        case open
        case halfOpen
    }
    
    open let timeout: TimeInterval
    open let maxRetries: Int
    open let timeBetweenRetries: TimeInterval
    open let exponentialBackoff: Bool
    open let resetTimeout: TimeInterval
    open var call: ((CircuitBreaker) -> Void)?
    open var didTrip: ((CircuitBreaker, Error?) -> Void)?
    open fileprivate(set) var failureCount = 0
    
    open var state: State {
        if let lastFailureTime = lastFailureTime
            , (failureCount > maxRetries) &&
                (Date().timeIntervalSince1970 - lastFailureTime) > resetTimeout {
                    return .halfOpen
        }
        
        if failureCount > maxRetries {
            return .open
        }
        
        return .closed
    }
    
    fileprivate var lastError: Error?
    fileprivate var lastFailureTime: TimeInterval?
    fileprivate var timer: Timer?
    
    public init(
        timeout: TimeInterval = 10,
        maxRetries: Int = 2,
        timeBetweenRetries: TimeInterval = 2,
        exponentialBackoff: Bool = true,
        resetTimeout: TimeInterval = 10) {
            self.timeout = timeout
            self.maxRetries = maxRetries
            self.timeBetweenRetries = timeBetweenRetries
            self.exponentialBackoff = exponentialBackoff
            self.resetTimeout = resetTimeout
    }
    
    // MARK: - Public API
    
    open func execute() {
        timer?.invalidate()
        
        switch state {
        case .closed, .halfOpen:
            doCall()
        case .open:
            trip()
        }
    }
    
    open func success() {
        reset()
    }
    
    open func failure(_ error: Error? = nil) {
        timer?.invalidate()
        lastError = error
        lastFailureTime = Date().timeIntervalSince1970
        failureCount += 1
        
        switch state {
        case .closed, .halfOpen:
            retryAfterDelay()
        case .open:
            trip()
        }
    }
    
    open func reset() {
        timer?.invalidate()
        failureCount = 0
        lastFailureTime = nil
        lastError = nil
    }
    
    // MARK: - Call & Timeout
    
    fileprivate func doCall() {
        call?(self)
        startTimer(delay: timeout, selector: #selector(didTimeout(_:)))
    }
    
    @objc fileprivate func didTimeout(_ timer: Timer) {
        failure()
    }
    
    // MARK: - Retry
    
    fileprivate func retryAfterDelay() {
        let delay = exponentialBackoff ? pow(timeBetweenRetries, Double(failureCount)) : timeBetweenRetries
        startTimer(delay: delay, selector: #selector(shouldRetry(_:)))
    }
    
    @objc fileprivate func shouldRetry(_ timer: Timer) {
        doCall()
    }
    
    // MARK: - Trip
    
    fileprivate func trip() {
        didTrip?(self, lastError)
    }
    
    // MARK: - Timer
    
    fileprivate func startTimer(delay: TimeInterval, selector: Selector) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: delay,
            target: self,
            selector: selector,
            userInfo: nil,
            repeats: false
        )
    }
    
}
