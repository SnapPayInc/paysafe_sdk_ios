//
//  ApplePayViewController.swift
//  Example
//
//  Created by Tsvetelina Stoyanova on 16.08.19.
//  Copyright © 2019 Paysafe. All rights reserved.
//

import UIKit
import Paysafe_SDK

class ApplePayViewController: UIViewController {
    @IBOutlet private var applePayButton: UIButton!
    @IBOutlet private var amountTextField: UITextField!
    @IBOutlet private var singleItemPriceTextField: UITextField!
    @IBOutlet private var errorMessageLabel: UILabel!
    @IBOutlet private var currencyLabel: UILabel!
    @IBOutlet private var activityIndicator: UIActivityIndicatorView!
    
    private enum Constants {
        static let unsupportedConfiguration = "Device does not support Apple Pay or some restrictions are set"
        static let successfulTransactionMessage = "Successfully completed transaction! "
        static let successfulTransactionTitle = "Success"
        static let invalidAmountMessage = "You've entered an invalid amount or price"
        static let invalidAmountTitle = "Invalid data"
        static let simulatorNotSupportedMessage = "Apple Pay transactions are not supported in simulator. Use real device instead."
    }
    
    private static let shippingMethodOptions = [
        ShippingMethod(price: NSDecimalNumber(string: "5.00"), title: "Carrier Pigeon", description: "You'll get it someday."),
        ShippingMethod(price: NSDecimalNumber(string: "100.00"), title: "Racecar", description: "Vrrrroom! Get it by tomorrow!"),
        ShippingMethod(price: NSDecimalNumber(string: "90000.00"), title: "Rocket Ship", description: "Look out your window!"),
    ]
    
    private var merchantBackend = MerchantSampleBackend()
    
    private lazy var applePayService = {
        return ApplePayService()
    }()
    
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                errorMessageLabel.isHidden = true
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
            activityIndicator.isHidden = !isLoading
            applePayButton.isEnabled = !isLoading
        }
    }
    
    func setupMerchantConfiguration() {
        PaysafeSDK.currentEnvironment = .test
        PaysafeSDK.merchantConfiguration = PaysafeSDK.MerchantConfiguration(username: "OT-484780", password: "B-qa2-0-5ef60470-0-302c02146c9e3f56c5b3f75f1294c95902614367b9b8e3cc0214731f3f0c77da66bbd0ba20c0af58251edd95f997", accountId: "1001739760")
        PaysafeSDK.applePayMerchantConfiguration = PaysafeSDK.ApplePayMerchantConfiguration(applePayMerchantId: "merchant.ca.snappay.snaplii.test", countryCode: "CA", currencyCode: "CAD")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        hideKeyboardWhenTappedAround()
        setupMerchantConfiguration()
        
        applePayButton.isHidden = !applePayService.isApplePaySupported()
        
        if applePayButton.isHidden {
            errorMessageLabel.text = Constants.unsupportedConfiguration
            errorMessageLabel.isHidden = false
        }
        
        amountTextField.text = "1"
        singleItemPriceTextField.text = "0.01"
        currencyLabel.text = PaysafeSDK.applePayMerchantConfiguration?.currencyCode
        isLoading = false
    }
    
    @IBAction private func startApplePayPayment(_ sender: Any) {
        guard let amount = amountValue(), let price = priceValue() else {
            displayAlert(title: Constants.invalidAmountTitle, message: Constants.invalidAmountMessage)
            return
        }
        
        let image = UIImage(named: "ellipsis")
        let product = Merchandise(image: image,
                                  title: "title",
                                  price: NSDecimalNumber(value: price),
                                  amount: amount,
                                  shippingType: .none,
                                  description: "")
        
        let cartData = CartDetails(cartId: "123423", payTo: "Payto......", shippingOptions:[])
        
        isLoading = true
        applePayService.beginPayment(product, cartDetails: cartData) { [weak self] result in
            self?.isLoading = false
            self?.didReceiveResultFromAppleService(result)
        }
    }
    
    private func priceValue() -> Double? {
        return Double(singleItemPriceTextField.text ?? "")
    }
    
    private func amountValue() -> Int? {
        return Int(amountTextField.text ?? "")
    }
    
    private func createTokenWithPayment(_ payment: PKPayment) -> ApplePayTokenWrapper? {
        let paymentData = payment.token.paymentData
        return ApplePayTokenWrapper.create(from: paymentData)
    }
    
    private func didReceiveResultFromAppleService(_ result: Result<PKPayment, Error>) {
        guard let _ = amountValue() else {
            displayAlert(title: Constants.invalidAmountTitle, message: Constants.invalidAmountMessage)
            return
        }
        
        switch result {
        case let .failure(error):
            displayError(error)
        case let .success(payment):
            #if targetEnvironment(simulator)
            var cardNum: String
            switch payment.token.paymentMethod.network {
            case PKPaymentNetwork.amex:
                cardNum = "370000000001091"
            case PKPaymentNetwork.masterCard:
                cardNum = "510000000001091"
            case PKPaymentNetwork.visa:
                cardNum = "400000000001091"
            default:
                cardNum = "400000000001091"
            }
            merchantBackend.createApplePaymentFakeToken(cardNum: cardNum) { result in
                switch result {
                case let .success(data):
                    self.storeToBackend(data)
                case let .failure(error):
                    self.displayAlert(title: Constants.unsupportedConfiguration, message: error.localizedDescription)
                }
            }
            #else
            guard let applePayInfo = createTokenWithPayment(payment) else {
                self.displayAlert(title: nil, message: Constants.simulatorNotSupportedMessage)
                return
            }
            self.storeToBackend(applePayInfo)
            #endif
        }
    }
    
    private func storeToBackend(_ applePayInfo: ApplePayTokenWrapper) {
        merchantBackend.sendApplePay(applePayInfo) { [weak self] applePayResult in
            switch applePayResult {
            case let .failure(error):
                self?.displayError(error)
            case .success(let info):
                print(info.paymentToken)
                let pasteboard = UIPasteboard.general
                pasteboard.string = info.paymentToken
                self?.displayAlert(title: Constants.successfulTransactionTitle, message: Constants.successfulTransactionMessage + info.paymentToken)
            }
        }
    }
}

extension ApplePayViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if amountTextField.isFirstResponder {
            singleItemPriceTextField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
        }
        return true
    }
}
