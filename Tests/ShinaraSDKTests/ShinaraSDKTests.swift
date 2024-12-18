import XCTest
import Testing
@testable import ShinaraSDK

let validApiKey = "VALID_KEY" // replace this with your actual API key
let invalidApiKey = "INVALID_API_KEY"

let validReferralCode = "TEST01" // replace this with your actual referral code
let invalidReferralCode = "INVALID_REFERRAL_CODE"

class ShinaraSDKTests: XCTestCase {
    func testInitializationSuccess() async throws {
        // Create an expectation for the async operation
        let expectation = expectation(description: "SDK initialization success")
        
        // Initialize SDK with invalid API key and completion handler
        await ShinaraSDK.shared.initialize(
            apiKey: validApiKey,
            completion: { result in
                switch result {
                case .success:
                expectation.fulfill()
                case .failure(let error):
                    XCTFail("Initialization should not fail with invalid API key")
                }
            }
        )
        
        // Wait for expectation with timeout
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testInitializationFailure() async throws {
        // Create an expectation for the async operation
        let expectation = expectation(description: "SDK initialization failure")
        
        // Initialize SDK with invalid API key and completion handler
        await ShinaraSDK.shared.initialize(
            apiKey: invalidApiKey,
            completion: { result in
                switch result {
                case .success:
                    XCTFail("Initialization should fail with invalid API key")
                case .failure(let error):
                    XCTAssertNotNil(error, "Error should not be nil")
                    expectation.fulfill()
                }
            }
        )
        
        // Wait for expectation with timeout
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testValidateReferralCodeSuccess() async throws {
        // First initialize the SDK
        let initExpectation = expectation(description: "SDK initialization")
        await ShinaraSDK.shared.initialize(apiKey: validApiKey) { result in
            if case .success = result {
                initExpectation.fulfill()
            }
        }
        await fulfillment(of: [initExpectation], timeout: 5.0)
        
        // Then test code validation
        let expectation = expectation(description: "Code validation success")
        
        await ShinaraSDK.shared.validateReferralCode(
            code: validReferralCode,
            completion: { result in
                switch result {
                case .success(let programId):
                    XCTAssertNotNil(programId, "Program ID should not be nil")
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Validation should not fail with valid code: \(error.localizedDescription)")
                }
            }
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)
    
        // Get referral code and verify it matches
        let storedCode = await ShinaraSDK.shared.getReferralCode()
        XCTAssertEqual(storedCode, validReferralCode, "Stored referral code should match the validated code")
    }

    func testRegisterUserSuccess() async throws {
        // First initialize the SDK
        let initExpectation = expectation(description: "SDK initialization")
        await ShinaraSDK.shared.initialize(apiKey: validApiKey) { result in
            if case .success = result {
                initExpectation.fulfill()
            }
        }
        await fulfillment(of: [initExpectation], timeout: 5.0)
        
        // Then validate referral code
        let validateExpectation = expectation(description: "Code validation")
        await ShinaraSDK.shared.validateReferralCode(code: validReferralCode) { result in
            if case .success = result {
                validateExpectation.fulfill()
            }
        }
        await fulfillment(of: [validateExpectation], timeout: 5.0)
        
        // Finally test user registration
        let expectation = expectation(description: "User registration success")
        
        let testUserId = "test_\(UUID().uuidString)"
        let testEmail: String? = nil
        let testName: String? = nil
        let testPhone: String? = nil
        
        await ShinaraSDK.shared.registerUser(
            userId: testUserId,
            email: testEmail,
            name: testName,
            phone: testPhone,
            completion: { result in
                switch result {
                case .success:
                    expectation.fulfill()
                case .failure(let error):
                    XCTFail("Registration should not fail: \(error.localizedDescription)")
                }
            }
        )
        
        await fulfillment(of: [expectation], timeout: 5.0)

        // Get user Id and verify it matches
        let storedUserId = await ShinaraSDK.shared.getUserId()
        XCTAssertEqual(storedUserId, testUserId, "Stored user Id should match the registered user Id")
    }

    // Helper method to reset SDK state between tests if needed
    override func setUp() async throws {
        try await super.setUp()
        // Clear UserDefaults between tests
        UserDefaults.standard.removeObject(forKey: "SHINARA_SDK_REFERRAL_CODE")
        UserDefaults.standard.removeObject(forKey: "SHINARA_SDK_EXTERNAL_USER_ID")
    }
    
    override func tearDown() async throws {
        // Add any cleanup code here
        try await super.tearDown()
    }
}