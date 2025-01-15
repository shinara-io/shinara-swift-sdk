# Shinara Swift SDK

This SDK provides a simple interface for integrating [Shinara](https://shinara.io/) functionality into your Swift application.

## Installation

### Swift Package Manager

```
dependencies: [
    .package(url: "https://github.com/shinara-io/shinara-swift-sdk.git", from: "1.0.1")
]
```

## Usage

### Import Library

```swift
import ShinaraSDK
```

### Initialize Client
Initializes Shinara SDK and monitors In App Purchases to Attribute Conversion

```swift
init() {
    ShinaraSDK.instance.initialize(apiKey: "API_KEY")
}
```

### Validate Referral Code
Validates Affiliate's Referral Code
Note: Call `validateReferralCode` before In App Purchase for successful Attribution linking of Purchase and Affiliate

```swift
ShinaraSDK.instance.validateReferralCode(code: referralCode) { result in
    switch result {
    case .success(let programId):
        // handle success
    case .failure(let error):
        // handle error
    }
}
```

### Attribute Purchase
To attribute a purchase. Recommended to call this after successful in app purchase. Shinara will handle logic to only attribute purchase coming from a referral code

```swift
ShinaraSDK.instance.handlePurchase(productId: transaction.payment.productIdentifier, transactionId: transaction.transactionIdentifier ?? "") { result in
    switch result {
    case .success(_):
        // handle success
    case .failure(let error):
        // handle error
    }
}
```

### Register a user (Optional)
By default, Shinara creates a new random userId and assign it to a conversion. Use `registerUser` if you want to use your own internal user id.
Note: Call `registerUser` before In App Purchase for successful Attribution linking of Purchase with your internal user id.

```swift
ShinaraSDK.instance.registerUser(userId: "INTERNAL_USER_ID", email: nil, name: nil, phone: nil) { result in
    switch result {
    case .success(_):
        // handle success            
    case .failure(let error):
        // handle error           
    }
}
```
