import XCTest
@testable import VCPromises

final class PromiseCatchTests: XCTestCase {

    enum SomeError: Error { case foo, bar }

    enum ComplexError: Error, Equatable {

        enum Reason {
            case parsingFailed
            case serviceError
        }

        case httpError(Int)
        case other(Reason)
    }

    func test_error_catch_after_reject() {

        let promise = Promise<Int>()
        promise.reject(SomeError.foo)

        let expectation = self.expectation(description: "waiting for promise with error after")
        promise.catch { _ in
            expectation.fulfill()
        }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_error_catch_before_reject() {
        let promise = Promise<Int>()

        let expectation = self.expectation(description: "waiting for promise with error before")
        promise.catch { _ in
            expectation.fulfill()
        }

        promise.reject(SomeError.foo)

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_then_error_catching() {

        let expectation = self.expectation(description: "waiting for promise that throws error")

        func someWork() throws -> Void {
            throw SomeError.foo
        }

        let work: Promise<Void>.Work = { fulfill, _ in
            fulfill(try someWork())
        }

        Promise(work, on: .global(qos: .userInitiated))
            .then(on: .main) { XCTFail() }
            .catch { _ in expectation.fulfill() }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_catch_after_multiple_rejects() {

        let expectation = self.expectation(description: "waiting for promise that throws error")
        expectation.expectedFulfillmentCount = 2

        let promise = Promise<Void>()

        promise.reject(SomeError.foo)
        promise.reject(SomeError.bar)

        promise.catch { expectation.fulfill(); XCTAssertEqual(($0 as? SomeError), SomeError.foo) }
        promise.catch { expectation.fulfill(); XCTAssertEqual(($0 as? SomeError), SomeError.foo) }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_thenMap_error_catching() {

        let expectation = self.expectation(description: "waiting for promise that throws error")

        let promise = Promise<Int>()
        promise.fulfill(1)

        promise
            .thenMap(on: .main) { _ in throw SomeError.foo }
            .catch { _ in expectation.fulfill() }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_catch_paricular_error() {

        let expectation = self.expectation(description: "waiting for promise that throws error")

        let promise = Promise<Void>(error: SomeError.foo)

        promise
            .catch(SomeError.foo) { expectation.fulfill() }
            .catch(SomeError.bar) { XCTFail() }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_catch_paricular_complex_error() {

        let expectation = self.expectation(description: "waiting for promise that throws error")
        expectation.expectedFulfillmentCount = 2

        let promise = Promise<Void>(error: ComplexError.httpError(401))

        promise
            .catch(ComplexError.httpError(401)) { expectation.fulfill() }
            .catch(SomeError.bar) { XCTFail() }

        let anotherPromise = Promise<Void>(error: ComplexError.other(.serviceError))

        anotherPromise
            .catch(ComplexError.other(.parsingFailed)) { XCTFail() }
            .catch(ComplexError.other(.serviceError)) { expectation.fulfill() }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_smart_catch() {
        let expectation = self.expectation(description: "waiting for promise that throws error")
        expectation.expectedFulfillmentCount = 2

        let promise = Promise<Void>()
        promise.reject(ComplexError.httpError(500))

        promise
            .catch(ComplexError.self) { error in
                switch error {
                case .httpError(500): expectation.fulfill()
                default: XCTFail()
                }
            }
            .catch(ComplexError.httpError(500)) {
                expectation.fulfill()
            }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_multiple_catches_with_different_types() {
        let expectation = self.expectation(description: "waiting for promise that throws error")
        expectation.expectedFulfillmentCount = 3

        let promise = Promise<Void>()
        promise.reject(ComplexError.httpError(500))

        promise
            .catch(ComplexError.httpError(500)) { expectation.fulfill() }
            .catch(ComplexError.self) { _ in expectation.fulfill() }
            .catch { _ in expectation.fulfill() }

        waitForExpectations(timeout: 0.1, handler: nil)
    }

    func test_catch_on_different_queues() {
        let expectation = self.expectation(description: "waiting for promise that throws error")
        expectation.expectedFulfillmentCount = 3

        let someQueue = DispatchQueue(label: "some.queue", attributes: .concurrent)
        let anotherQueue = DispatchQueue(label: "another.queue", attributes: .concurrent)

        let promise = Promise<Void>(error: SomeError.foo)

        promise.catch(on: .main) { _ in XCTAssertEqual(currentQueueLabel, "com.apple.main-thread"); expectation.fulfill() }
        promise.catch(on: someQueue) { _ in XCTAssertEqual(currentQueueLabel, "some.queue"); expectation.fulfill() }
        promise.catch(on: anotherQueue) { _ in XCTAssertEqual(currentQueueLabel, "another.queue"); expectation.fulfill() }

        waitForExpectations(timeout: 0.1, handler: nil)
    }
}
