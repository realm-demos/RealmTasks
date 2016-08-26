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

import Realm // FIXME: Use Realm Swift once it can create non-synced Realms again.
import RealmSwift

let user = RealmSwift.User(localIdentity: nil)
func credentialForUsername(username: String, password: String, register: Bool) -> Credential {
    return Credential(credentialToken: username,
                      provider: RLMIdentityProviderUsernamePassword,
                      userInfo: ["password": password, "register": register],
                      serverURL: Constants.syncServerURL)
}

func setupRealmSyncAndInitialList() {
    configureRealmServerWithAppID(Constants.appID, logLevel: 0, globalErrorHandler: nil)
    syncRealmConfiguration.setObjectServerPath("/~/realmtasks", for: user)
    Realm.Configuration.defaultConfiguration = syncRealmConfiguration

    do {
        let realm = try Realm()
        if realm.isEmpty {
            // Create an initial list if none exist
            try realm.write {
                let list = TaskList()
                list.id = ""
                list.text = Constants.defaultListName
                let listLists = TaskListList()
                listLists.items.append(list)
                realm.add(listLists)
            }
        }
    } catch {
        fatalError("Could not open or write to the realm: \(error)")
    }
}

func logInWithPersistedUser(callback: (NSError?) -> ()) {
    // FIXME: Use Realm Swift once it can create non-synced Realms again.
    if let realm = try? RLMRealm(configuration: userRealmConfiguration),
        let persistedUser = PersistedUser.allObjectsInRealm(realm).firstObject() as? PersistedUser {
        let credential = credentialForUsername(persistedUser.username, password: persistedUser.password, register: false)
        user.loginWithCredential(credential, completion: callback)
    } else {
        callback(NSError(domain: "io.realm.RealmTasks", code: 0, userInfo: nil))
    }
}

func persistUserAndLogInWithUsername(username: String, password: String, register: Bool, callback: (NSError?) -> ()) {
    // FIXME: Use Realm Swift once it can create non-synced Realms again.
    dispatch_async(dispatch_queue_create("io.realm.RealmTasks.bg", nil)) {
        let userRealm = try! RLMRealm(configuration: userRealmConfiguration)
        try! userRealm.transactionWithBlock {
            let user = PersistedUser()
            user.username = username
            user.password = password
            userRealm.addObject(user)
        }
    }
    let credential = credentialForUsername(username, password: password, register: register)
    user.loginWithCredential(credential, completion: callback)
}
