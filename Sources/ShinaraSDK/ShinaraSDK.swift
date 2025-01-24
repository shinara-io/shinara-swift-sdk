import Foundation
import Alamofire
import StoreKit

// Response models remain the same
struct KeyValidationResponse: Codable {
    let appId: String
    let trackRetention: Bool?
    
    enum CodingKeys: String, CodingKey {
        case appId = "app_id"
        case trackRetention = "track_retention"
    }
}

struct ValidationResponse: Codable {
    let programId: String?
    let codeId: String?
    
    enum CodingKeys: String, CodingKey {
        case programId = "campaign_id"
        case codeId = "affiliate_code_id"
    }
}

struct ConversionUser: Codable {
    let externalUserId: String
    let name: String?
    let email: String?
    let phone: String?
    let autoGeneratedExternalUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case externalUserId = "external_user_id"
        case name
        case email
        case phone
        case autoGeneratedExternalUserId = "auto_generated_external_user_id"
    }
}

struct TriggerAppOpenRequest: Codable {
    let codeId: String
    let externalUserId: String?
    let autoGeneratedExternalUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case codeId = "affiliate_code_id"
        case externalUserId = "external_user_id"
        case autoGeneratedExternalUserId = "auto_generated_external_user_id"
    }
}

struct UserRegistrationRequest: Codable {
    let code: String
    let platform: String
    let conversionUser: ConversionUser
    let codeId: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case platform
        case conversionUser = "conversion_user"
        case codeId = "affiliate_code_id"
    }
}

public actor ShinaraSDK {
    public static let instance = ShinaraSDK()
    private var apiKey: String?
    private var baseURL: String = "https://sdk-gateway-b85kv8d1.ue.gateway.dev"
    
    private let referralCodeKey = "SHINARA_SDK_REFERRAL_CODE"
    private let programIdKey = "SHINARA_SDK_PROGRAM_ID"
    private let referralCodeIdKey = "SHINARA_SDK_REFERRAL_CODE_ID"
    private let userExternalIdKey = "SHINARA_SDK_EXTERNAL_USER_ID"
    private let autoGenUserExternalIdKey = "SHINARA_SDK_AUTO_GEN_EXTERNAL_USER_ID"
    private let processedTransactionsKey = "SHINARA_SDK_PROCESSED_TRANSACTIONS"
    private let registeredUsersKey = "SHINARA_SDK_REGISTERED_USERS"
    private let apiHeaderKey = "X-API-Key"
    private let sdkPlatformHeaderKey = "X-SDK-Platform"
    private let sdkPlatformHeaderValue = "ios"
    
    private let referralParamKey = "shinara_ref_code"
    
    private init() {}
    
    public func initialize(apiKey: String) async throws {
        self.apiKey = apiKey
        let validationResponse = try await validateAPIKey()
        if let trackRetention = validationResponse.trackRetention, trackRetention {
            triggerAppOpen()
        }
        print("Shinara SDK Initialized")
    }
    
    private func validateAPIKey() async throws -> KeyValidationResponse {
        guard let apiKey = apiKey else {
            throw NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set"])
        }

        let headers: HTTPHeaders = [self.apiHeaderKey: apiKey, self.sdkPlatformHeaderKey: sdkPlatformHeaderValue]
        let response = await AF.request("\(baseURL)/api/key/validate", headers: headers).serializingData().response

        guard let statusCode = response.response?.statusCode else {
            throw NSError(domain: "ShinaraSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
        }

        if statusCode == 200, let data = response.data {
            let validationResponse = try JSONDecoder().decode(KeyValidationResponse.self, from: data)
            return validationResponse // Success!
        } else {
            throw NSError(domain: "ShinaraSDK", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "API Key validation failed"])
        }
    }
    
    public func handleDeepLink(url: URL) async throws {
        if let localApiKey = apiKey, !localApiKey.isEmpty {
            // fetch key first
            try await validateAPIKey()
        }
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
           let queryItems = components.queryItems {
            for item in queryItems {
                if item.name == referralParamKey {
                    if let code = item.value, !code.isEmpty {
                        try await validateReferralCode(code: code)
                    }
                }
            }
        }
    }
    
    public func validateReferralCode(code: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set"])
        }

        let parameters = ["code": code]
        let headers: HTTPHeaders = [self.apiHeaderKey: apiKey, self.sdkPlatformHeaderKey: sdkPlatformHeaderValue]

        let response = await AF.request(
            "\(self.baseURL)/api/code/validate",
            method: .post,
            parameters: parameters,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ).serializingData().response

        guard let statusCode = response.response?.statusCode else {
            throw NSError(domain: "ShinaraSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
        }

        if statusCode == 200, let data = response.data {
            let validationResponse = try JSONDecoder().decode(ValidationResponse.self, from: data)
            if let programId = validationResponse.programId, !programId.isEmpty {
                UserDefaults.standard.set(code, forKey: self.referralCodeKey)
                UserDefaults.standard.set(programId, forKey: self.programIdKey)
                if let codeId = validationResponse.codeId, !codeId.isEmpty {
                    UserDefaults.standard.set(codeId, forKey: self.referralCodeIdKey)
                }
                return programId
            } else {
                throw NSError(domain: "ShinaraSDK", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Referral code validation failed"])
            }
        } else {
            throw NSError(domain: "ShinaraSDK", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Referral code validation failed"])
        }
    }

    private func triggerAppOpen() {
        Task {
            guard let apiKey = apiKey else {
                return
            }

            guard let referralCodeId = UserDefaults.standard.string(forKey: self.referralCodeIdKey) else {
                return
            }
            
            let externalUserId = UserDefaults.standard.string(forKey: self.userExternalIdKey)
            let autoGeneratedExternalUserId = UserDefaults.standard.string(forKey: self.autoGenUserExternalIdKey)

            let headers: HTTPHeaders = [self.apiHeaderKey: apiKey, self.sdkPlatformHeaderKey: sdkPlatformHeaderValue]
            let request = TriggerAppOpenRequest(
                codeId: referralCodeId,
                externalUserId: externalUserId,
                autoGeneratedExternalUserId: autoGeneratedExternalUserId
            )

            _ = await AF.request(
                "\(self.baseURL)/appopen",
                method: .post,
                parameters: request,
                encoder: JSONParameterEncoder.default,
                headers: headers
            ).serializingData().response
        }
    }
    
    public func getReferralCode() -> String? {
        UserDefaults.standard.string(forKey: referralCodeKey)
    }
    
    public func getProgramId() -> String? {
        UserDefaults.standard.string(forKey: programIdKey)
    }
    
    public func registerUser(userId: String, email: String?, name: String?, phone: String?) async throws {
        guard let apiKey = apiKey else {
            throw NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set"])
        }

        guard let referralCode = UserDefaults.standard.string(forKey: self.referralCodeKey) else {
            throw NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "No stored referral code found. Please save a referral code before registering a user."])
        }
        
        var registeredUsers = UserDefaults.standard.array(forKey: self.registeredUsersKey) as? [String] ?? []
        if registeredUsers.contains(userId) {
            return // Skip if already registered
        }

        let headers: HTTPHeaders = [self.apiHeaderKey: apiKey, self.sdkPlatformHeaderKey: sdkPlatformHeaderValue]
        let conversionUser = ConversionUser(
            externalUserId: userId,
            name: name,
            email: email,
            phone: phone,
            autoGeneratedExternalUserId: UserDefaults.standard.string(forKey: self.autoGenUserExternalIdKey)
        )
        
        let codeId = UserDefaults.standard.string(forKey: self.referralCodeIdKey)

        let request = UserRegistrationRequest(
            code: referralCode,
            platform: "",
            conversionUser: conversionUser,
            codeId: codeId
        )

        let response = await AF.request(
            "\(self.baseURL)/newuser",
            method: .post,
            parameters: request,
            encoder: JSONParameterEncoder.default,
            headers: headers
        ).serializingData().response

        guard let statusCode = response.response?.statusCode else {
            throw NSError(domain: "ShinaraSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
        }

        if statusCode == 200 {
            UserDefaults.standard.set(userId, forKey: self.userExternalIdKey)
            UserDefaults.standard.removeObject(forKey: self.autoGenUserExternalIdKey)
            registeredUsers.append(userId)
            UserDefaults.standard.set(registeredUsers, forKey: self.registeredUsersKey)
        } else {
            throw NSError(domain: "ShinaraSDK", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "User registration failed"])
        }
    }
    
    public func getUserId() -> String? {
        UserDefaults.standard.string(forKey: userExternalIdKey)
    }
    
    public func attributePurchase(productId: String, transactionId: String) async throws {
        guard let apiKey = apiKey else {
            throw NSError(domain: "ShinaraSDK", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not set"])
        }

        guard let referralCode = UserDefaults.standard.string(forKey: self.referralCodeKey) else {
            // If no referral code, we can still proceed without sending a purchase attribution.
            return
        }

        var processedTransactions = UserDefaults.standard.array(forKey: self.processedTransactionsKey) as? [String] ?? []
        if processedTransactions.contains(transactionId) {
            return // Skip if already processed
        }

        let headers: HTTPHeaders = [self.apiHeaderKey: apiKey, self.sdkPlatformHeaderKey: sdkPlatformHeaderValue]
        var parameters: [String: String] = [
            "product_id": productId,
            "transaction_id": transactionId,
            "code": referralCode,
            "platform": ""
        ]
        
        if let codeId = UserDefaults.standard.string(forKey: self.referralCodeIdKey) {
            parameters["affiliate_code_id"] = codeId
        }

        if let externalUserId = UserDefaults.standard.string(forKey: self.userExternalIdKey) {
            parameters["external_user_id"] = externalUserId
        } else {
            let autoSDKGenExternalUserId: String = UUID().uuidString
            UserDefaults.standard.set(autoSDKGenExternalUserId, forKey: self.autoGenUserExternalIdKey)
            parameters["auto_generated_external_user_id"] = autoSDKGenExternalUserId
        }

        let response = await AF.request(
            "\(self.baseURL)/iappurchase",
            method: .post,
            parameters: parameters,
            encoding: JSONEncoding.default,
            headers: headers
        ).serializingData().response

        guard let statusCode = response.response?.statusCode else {
            throw NSError(domain: "ShinaraSDK", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error occurred"])
        }

        if statusCode == 200 {
            processedTransactions.append(transactionId)
            UserDefaults.standard.set(processedTransactions, forKey: self.processedTransactionsKey)
        } else {
            throw NSError(domain: "ShinaraSDK", code: statusCode, userInfo: [NSLocalizedDescriptionKey: "Purchase attribution failed"])
        }
    }
}
