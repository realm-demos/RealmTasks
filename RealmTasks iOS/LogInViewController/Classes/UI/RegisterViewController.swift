////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016 Realm Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
////////////////////////////////////////////////////////////////////////////

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
