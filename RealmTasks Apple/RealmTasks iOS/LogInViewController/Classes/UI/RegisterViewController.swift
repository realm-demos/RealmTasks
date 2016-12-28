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

    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var confirmationTextField: UITextField!
    @IBOutlet weak var registerButton: UIButton!

    var initialUserName: String?
    var completionHandler: ((_ userName: String?, _ password: String?, _ returnCode: RegisterViewControllerReturnCode) -> Void)?

    override func viewDidLoad() {
        userNameTextField.addTarget(self, action: #selector(updateUI), for: .editingChanged)
        passwordTextField.addTarget(self, action: #selector(updateUI), for: .editingChanged)
        confirmationTextField.addTarget(self, action: #selector(updateUI), for: .editingChanged)

        if let userName = initialUserName, !userName.isEmpty {
            userNameTextField.text = userName
            passwordTextField.becomeFirstResponder()
        } else {
            userNameTextField.becomeFirstResponder()
        }

        updateUI()
    }

    @IBAction func register(sender: AnyObject?) {
        guard userInputValid() else {
            return
        }

        dismiss(animated: true) {
            self.completionHandler?(self.userNameTextField.text, self.passwordTextField.text, .Register)
        }
    }

    @IBAction func cancel(sender: AnyObject?) {
        dismiss(animated: true) {
            self.completionHandler?(nil, nil, .Cancel)
        }
    }

    private dynamic func updateUI() {
        registerButton.isEnabled = userInputValid()
    }

    private func userInputValid() -> Bool {
        guard
            let userName = userNameTextField.text, userName.characters.count > 0,
            let password = passwordTextField.text, password.characters.count > 0,
            let confirmation = confirmationTextField.text, confirmation == password
        else {
            return false
        }

        return true
    }

}

extension RegisterViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == userNameTextField {
            passwordTextField.becomeFirstResponder()
        } else if textField == passwordTextField {
            confirmationTextField.becomeFirstResponder()
        } else if textField == confirmationTextField {
            register(sender: nil)
        }

        return false
    }

}

extension RegisterViewController: UINavigationBarDelegate {

    func positionForBar(bar: UIBarPositioning) -> UIBarPosition {
        return .topAttached
    }

}
