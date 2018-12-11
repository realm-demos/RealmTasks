//
//  RootViewController.swift
//  RealmTasks iOS
//
//  Created by Kishikawa Katsumi on 2017/12/01.
//  Copyright © 2017 Realm. All rights reserved.
//

import UIKit
import RealmLoginKit

class RootViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        setAuthenticationFailureCallback {
            resetDefaultRealm()
            self.logIn()
        }
        if configureDefaultRealm() {
            let containerViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ContainerViewController")
            navigationController?.pushViewController(containerViewController, animated: false)
        } else {
            logIn(animated: false)
        }
    }

    func logIn(animated: Bool = true) {
        let loginController = LoginViewController(style: .darkTranslucent)
        loginController.isServerURLFieldHidden = true
        loginController.isRememberAccountDetailsFieldHidden = true
        loginController.serverURL = Constants.syncAuthURL.absoluteString
        loginController.loginSuccessfulHandler = { user in
            setDefaultRealmConfiguration(with: user)
            let containerViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ContainerViewController")
            self.navigationController?.pushViewController(containerViewController, animated: false)
            self.dismiss(animated: true, completion: nil)
        }

        navigationController?.present(loginController, animated: false, completion: nil)
    }

    func present(error: NSError) {
        let alertController = UIAlertController(title: error.localizedDescription,
                                                message: error.localizedFailureReason ?? "",
                                                preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Try Again", style: .default) { _ in
            self.logIn()
        })
        present(alertController, animated: true, completion: nil)
    }
}
