/*************************************************************************
 *
 * REALM CONFIDENTIAL
 * __________________
 *
 *  [2016] Realm Inc
 *  All Rights Reserved.
 *
 * NOTICE:  All information contained herein is, and remains
 * the property of Realm Incorporated and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Realm Incorporated
 * and its suppliers and may be covered by U.S. and Foreign Patents,
 * patents in process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Realm Incorporated.
 *
 **************************************************************************/

import UIKit
import FBSDKLoginKit

public typealias RealmSyncLoginCompletionHandler = (accessToken: String?, error: NSError?) -> Void

public class RealmSyncLoginManager: NSObject {

    let authURL: NSURL
    let appID: String
    let realmPath: String

    private let loginStoryboard = UIStoryboard(name: "RealmSyncLogin", bundle: NSBundle.mainBundle())

    public init(authURL: NSURL, appID: String, realmPath: String) {
        self.authURL = authURL
        self.appID = appID
        self.realmPath = realmPath
    }

    public func logIn(fromViewController parentViewController: UIViewController, completion: RealmSyncLoginCompletionHandler?) {
        guard let logInViewController = loginStoryboard.instantiateInitialViewController() as? LogInViewController else {
            fatalError()
        }

        logInViewController.completionHandler = { userName, password, facebookAccessToken, returnCode in
            switch returnCode {
            case .LogIn:
                self.logIn(userName: userName!, password: password!, completion: completion)
            case .Register:
                self.register(userName: userName!, password: password!, completion: completion)
            case .FacebookLogIn:
                self.logIn(facebookAccessToken: facebookAccessToken!, completion: completion)
            case .Cancel:
                completion?(accessToken: nil, error: nil)
            }
        }

        parentViewController.presentViewController(logInViewController, animated: true, completion: nil)
    }

    public func logIn(userName userName: String, password: String, completion: RealmSyncLoginCompletionHandler?) {
        let json = [
            "provider": "password",
            "data": userName,
            "password": password,
            "app_id": appID,
            "path": realmPath
        ]
        
        try! HTTPClient.post(authURL, json: json) { data, response, error in
            if let data = data {
                do {
                    let token = try self.parseResponseData(data)
                    
                    completion?(accessToken: token, error: nil)
                } catch let error as NSError {
                    completion?(accessToken: nil, error: error)
                }
            } else {
                completion?(accessToken: nil, error: error)
            }
        }
    }

    public func logIn(facebookAccessToken accessToken: String, completion: RealmSyncLoginCompletionHandler?) {
        let json = [
            "provider": "facebook",
            "data": accessToken,
            "app_id": appID,
            "path": realmPath
        ]

        try! HTTPClient.post(authURL, json: json) { data, response, error in
            if let data = data {
                do {
                    let token = try self.parseResponseData(data)

                    completion?(accessToken: token, error: nil)
                } catch let error as NSError {
                    completion?(accessToken: nil, error: error)
                }
            } else {
                completion?(accessToken: nil, error: error)
            }
        }
    }

    public func register(userName userName: String, password: String, completion: RealmSyncLoginCompletionHandler?) {
        let json = [
            "provider": "password",
            "data": userName,
            "password": password,
            "register": 1,
            "app_id": appID,
            "path": realmPath
        ]

        try! HTTPClient.post(authURL, json: json) { data, response, error in
            if let data = data {
                do {
                    let token = try self.parseResponseData(data)

                    completion?(accessToken: token, error: nil)
                } catch let error as NSError {
                    completion?(accessToken: nil, error: error)
                }
            } else {
                completion?(accessToken: nil, error: error)
            }
        }
    }

    public func logOut() {
        // TODO: implement
    }

    public class func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        return FBSDKApplicationDelegate
            .sharedInstance()
            .application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    public class func application(application: UIApplication!, openURL url: NSURL!, sourceApplication: String!, annotation: AnyObject!) -> Bool {
        return FBSDKApplicationDelegate
            .sharedInstance()
            .application(application, openURL: url, sourceApplication: sourceApplication, annotation: annotation)
    }

    private func parseResponseData(data: NSData) throws -> String {
        let json = try NSJSONSerialization.JSONObjectWithData(data, options: []) as? [String: AnyObject]

        guard let token = json?["token"] as? String else {
            let errorDescription = json?["error"] as? String ?? "Failed getting token"

            throw NSError(domain: "io.realm.sync.auth", code: 0, userInfo: [NSLocalizedDescriptionKey: errorDescription])
        }

        return token
    }
}
