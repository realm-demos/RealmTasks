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

import Foundation
import RealmSwift

// Private Helpers

private var realm: Realm! // FIXME: shouldn't have to hold on to the Realm here
private let userRealmConfiguration = Realm.Configuration(
    fileURL: NSURL.fileURLWithPath(NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]).URLByAppendingPathComponent("user.realm"),
    objectTypes: [PersistedUser.self]
)

private func setDefaultRealmConfigurationWithUser(user: User) {
    Realm.Configuration.defaultConfiguration = Realm.Configuration(
        syncConfiguration: (user, Constants.syncServerURL!),
        objectTypes: [TaskListList.self, TaskList.self, Task.self]
    )
    realm = try! Realm()
}

// Internal Functions

// returns true on success
func configureDefaultRealm() -> Bool {
    if let userRealm = try? Realm(configuration: userRealmConfiguration),
        let user = userRealm.objects(PersistedUser.self).first?.user {
        setDefaultRealmConfigurationWithUser(user)
        return true
    }
    return false
}

func authenticate(username username: String, password: String, register: Bool, callback: (User?, NSError?) -> ()) {
    User.authenticateWithCredential(.UsernamePassword(username: username, password: password),
                                    actions: register ? [.CreateAccount] : [],
                                    authServerURL: Constants.syncAuthURL) { user, error in
        if let user = user {
            setDefaultRealmConfigurationWithUser(user)
            dispatch_async(dispatch_queue_create("io.realm.RealmTasks.bg", nil)) {
                let userRealm = try! Realm(configuration: userRealmConfiguration)
                try! userRealm.write {
                    userRealm.add(PersistedUser(user: user))
                }
            }
            try! realm.write {
                let list = TaskList()
                list.id = ""
                list.text = Constants.defaultListName
                let listLists = TaskListList()
                listLists.items.append(list)
                realm.add(listLists)
            }
        }
        callback(user, error)
    }
}
