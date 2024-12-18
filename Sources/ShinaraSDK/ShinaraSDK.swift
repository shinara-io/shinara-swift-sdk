import Foundation
import Alamofire
import StoreKit

// Response models remain the same
struct ValidationResponse: Codable {
    let programId: String?
    
    enum CodingKeys: String, CodingKey {
        case programId = "campaign_id"
    }
}

struct ConversionUser: Codable {
    let externalUserId: String
    let name: String?
    let email: String?
    let phone: String?
    
    enum CodingKeys: String, CodingKey {
        case externalUserId = "external_user_id"
        case name
        case email
        case phone
    }
}

struct UserRegistrationRequest: Codable {
    let code: String
    let platform: String
    let conversionUser: ConversionUser
    
    enum CodingKeys: String, CodingKey {
        case code
        case platform
        case conversionUser = "conversion_user"
    }
}

public class ShinaraSDK: NSObject, SKPaymentTransactionObserver, @unchecked Sendable {
    public static let instance = ShinaraSDK()
    private var apiKey: String?
    private var baseURL: String = "https://sdk-gateway-b85kv8d1.ue.gateway.dev"
    
    private let referralCodeKey = "SHINARA_SDK_REFERRAL_CODE"
    private let userExternalIdKey = "SHINARA_SDK_EXTERNAL_USER_ID"
    private let apiHeaderKey = "X-API-Key"
    
    // Serial queue for thread-safe access to shared resources
    private let queue = DispatchQueue(label: "io.shinara.sdk.queue")

    private override init() {
        super.init()
    }

    public func initialize(apiKey: String) {
        queue.async { [weak self] in
            self?.apiKey = apiKey
            self?.validateAPIKey { result in
                switch result {
                case .success:
                    // Add StoreKit observer after successful validation
                    DispatchQueue.main.async {
                        SKPaymentQueue.default().add(self!)
                        print("Shinara SDK Initialized")
                    }
                case .failure(let error):
                    print("Failed to Initialize Shinara SDK: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func validateAPIKey(completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        guard let apiKey = apiKey else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set"])))
            }
            return
        }

        let headers: HTTPHeaders = [apiHeaderKey: apiKey]
        AF.request("\(baseURL)/api/key/validate", headers: headers).response { response in
            DispatchQueue.main.async {
                if let statusCode = response.response?.statusCode {
                    if statusCode == 200 {
                        completion(.success(()))
                    } else {
                        let error = NSError(
                            domain: "ShinaraSDK",
                            code: statusCode,
                            userInfo: [NSLocalizedDescriptionKey: "API Key validation failed"]
                        )
                        completion(.failure(error))
                    }
                } else if let error = response.error {
                    completion(.failure(error))
                } else {
                    completion(.failure(NSError(
                        domain: "ShinaraSDK",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                    )))
                }
            }
        }
    }

    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            guard let transactionId = transaction.transactionIdentifier else {
                continue
            }
            
            switch transaction.transactionState {
            case .purchased, .restored:
                handlePurchase(
                    productId: transaction.payment.productIdentifier,
                    transactionId: transaction.transactionIdentifier ?? ""
                ) { result in
                    switch result {
                    case .success:
                        queue.finishTransaction(transaction)
                    case .failure(let error):
                        print("Failed to attribute Shinara SDK transaction: \(error.localizedDescription)")
                        queue.finishTransaction(transaction)
                    }
                }
            case .failed:
                queue.finishTransaction(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }

    public func validateReferralCode(code: String, completion: @escaping @Sendable (Result<String, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let apiKey = self.apiKey else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "Shinara SDK API Key is not set."])))
                }
                return
            }

            let parameters = ["code": code]
            let headers: HTTPHeaders = [self.apiHeaderKey: apiKey]

            AF.request(
                "\(self.baseURL)/api/code/validate",
                method: .post,
                parameters: parameters,
                encoder: JSONParameterEncoder.default,
                headers: headers
            ).response { response in
                DispatchQueue.main.async {
                    if let statusCode = response.response?.statusCode {
                        if statusCode == 200 {
                            if let data = response.data {
                                do {
                                    let validationResponse = try JSONDecoder().decode(ValidationResponse.self, from: data)
                                    UserDefaults.standard.set(code, forKey: self.referralCodeKey)
                                    if validationResponse.programId == nil || validationResponse.programId?.isEmpty ?? false {
                                        let error = NSError(
                                            domain: "ShinaraSDK",
                                            code: statusCode,
                                            userInfo: [NSLocalizedDescriptionKey: "Referral code validation failed"]
                                        )
                                        completion(.failure(error))
                                    } else {
                                        completion(.success(validationResponse.programId ?? ""))
                                    }
                                } catch {
                                    completion(.failure(NSError(
                                        domain: "ShinaraSDK",
                                        code: -1,
                                        userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                                    )))
                                }
                            } else {
                                completion(.failure(NSError(
                                    domain: "ShinaraSDK",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                                )))
                            }
                        } else {
                            let error = NSError(
                                domain: "ShinaraSDK",
                                code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "Referral code validation failed"]
                            )
                            completion(.failure(error))
                        }
                    } else if let error = response.error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(NSError(
                            domain: "ShinaraSDK",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                        )))
                    }
                }
            }
        }
    }
    
    public func getReferralCode() -> String? {
        queue.sync {
            return UserDefaults.standard.string(forKey: referralCodeKey)
        }
    }
    
    public func getUserId() -> String? {
        queue.sync {
            return UserDefaults.standard.string(forKey: userExternalIdKey)
        }
    }

    public func registerUser(userId: String, email: String?, name: String?, phone: String?, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let apiKey = self.apiKey else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set."])))
                }
                return
            }
            
            guard let referralCode = UserDefaults.standard.string(forKey: self.referralCodeKey) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "No stored referral code found. Please save a referral code before registering a user."])))
                }
                return
            }

            let headers: HTTPHeaders = [self.apiHeaderKey: apiKey]
            
            let conversionUser = ConversionUser(
                externalUserId: userId,
                name: name,
                email: email,
                phone: phone
            )
            
            let request = UserRegistrationRequest(
                code: referralCode,
                platform: "",
                conversionUser: conversionUser
            )

            AF.request(
                "\(self.baseURL)/newuser",
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: headers
            ).response { response in
                DispatchQueue.main.async {
                    if let statusCode = response.response?.statusCode {
                        if statusCode == 200 {
                            UserDefaults.standard.set(userId, forKey: self.userExternalIdKey)
                            completion(.success(()))
                        } else {
                            let error = NSError(
                                domain: "ShinaraSDK",
                                code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "User registration failed"]
                            )
                            completion(.failure(error))
                        }
                    } else if let error = response.error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(NSError(
                            domain: "ShinaraSDK",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                        )))
                    }
                }
            }
        }
    }

    private func handlePurchase(productId: String, transactionId: String, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard let apiKey = self.apiKey else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set."])))
                }
                return
            }
            
            guard let referralCode = UserDefaults.standard.string(forKey: self.referralCodeKey) else {
                DispatchQueue.main.async {
                    completion(.success(()))
                }
                return
            }

            let headers: HTTPHeaders = [self.apiHeaderKey: apiKey]
            
            var parameters: [String: String] = [
                "product_id": productId,
                "transaction_id": transactionId,
                "code": referralCode,
                "platform": ""
            ]
            
            if let externalUserId = UserDefaults.standard.string(forKey: self.userExternalIdKey) {
                parameters["external_user_id"] = externalUserId
            }

            AF.request(
                "\(self.baseURL)/iappurchase",
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: headers
            ).response { response in
                DispatchQueue.main.async {
                    if let statusCode = response.response?.statusCode {
                        if statusCode == 200 {
                            completion(.success(()))
                        } else {
                            let error = NSError(
                                domain: "ShinaraSDK",
                                code: statusCode,
                                userInfo: [NSLocalizedDescriptionKey: "Purchase attribution failed"]
                            )
                            completion(.failure(error))
                        }
                    } else if let error = response.error {
                        completion(.failure(error))
                    } else {
                        completion(.failure(NSError(
                            domain: "ShinaraSDK",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"]
                        )))
                    }
                }
            }
        }
    }

    deinit {
        SKPaymentQueue.default().remove(self)
    }
}
