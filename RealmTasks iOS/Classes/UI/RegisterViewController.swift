//
//  RegisterViewController.swift
//  RealmSyncAuth
//
//  Created by Dmitry Obukhov on 27/06/16.
//  Copyright © 2016 Realm Inc. All rights reserved.
//

import UIKit

enum RegisterViewControllerReturnCode: Int {
    case Register
    case Cancel
}

class RegisterViewController: UIViewController {

    @IBOutlet private weak var userNameTextField: UITextField!
    @IBOutlet private weak var passwordTextField: UITextField!
    @IBOutlet private weak var confirmationTextField: UITextField!
    @IBOutlet private weak var registerButton: UIButton!

    var completionHandler: ((userName: String?, password: String?, returnCode: RegisterViewControllerReturnCode) -> ())?

    override func viewDidLoad() {
        userNameTextField.addTarget(self, action: #selector(updateUI), forControlEvents: .EditingChanged)
        passwordTextField.addTarget(self, action: #selector(updateUI), forControlEvents: .EditingChanged)
        confirmationTextField.addTarget(self, action: #selector(updateUI), forControlEvents: .EditingChanged)

        updateUI()
    }

    @IBAction func register(sender: AnyObject?) {
        guard userInputValid() else {
            return
        }

        dismissViewControllerAnimated(true) {
            self.completionHandler?(userName: self.userNameTextField.text, password: self.passwordTextField.text, returnCode: .Register)
        }
    }

    @IBAction func cancel(sender: AnyObject?) {
        dismissViewControllerAnimated(true) {
            self.completionHandler?(userName: nil, password: nil, returnCode: .Cancel)
        }
    }

    private dynamic func updateUI() {
        registerButton.enabled = userInputValid()
    }

    private func userInputValid() -> Bool {
        guard
            let userName = userNameTextField.text where userName.characters.count > 0,
            let password = passwordTextField.text where password.characters.count > 0,
            let confirmation = confirmationTextField.text where confirmation == password
        else {
            return false
        }

        return true
    }

}

extension RegisterViewController: UITextFieldDelegate {

    func textFieldShouldReturn(textField: UITextField) -> Bool {
        if textField == userNameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            confirmationTextField.becomeFirstResponder()
        } else if textField == confirmationTextField {
            register(nil)
        }

        return false
    }

}

extension RegisterViewController: UINavigationBarDelegate {

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .TopAttached
    }

}
