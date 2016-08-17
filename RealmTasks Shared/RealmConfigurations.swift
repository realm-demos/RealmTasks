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
import Realm // FIXME: Use Realm Swift once it can create non-synced Realms again.
import RealmSwift

let userRealmConfiguration: RLMRealmConfiguration = {
    let config = RLMRealmConfiguration()
    config.fileURL = NSURL.fileURLWithPath(NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]).URLByAppendingPathComponent("user.realm")
    config.objectClasses = [PersistedUser.self]
    return config
}()

let listsRealmConfiguration: Realm.Configuration = {
    struct SharedConfiguration {
        static var configuration: Realm.Configuration? = nil
    }

    if SharedConfiguration.configuration == nil {
        SharedConfiguration.configuration = Realm.Configuration()
        SharedConfiguration.configuration!.fileURL = Realm.Configuration().fileURL!.URLByDeletingLastPathComponent?.URLByAppendingPathComponent("lists.realm")
        SharedConfiguration.configuration!.objectTypes = [TaskListList.self, TaskListReference.self]
        SharedConfiguration.configuration!.setObjectServerPath(Constants.syncRealmPath + "/lists", for: Constants.user)
    }

    return SharedConfiguration.configuration!
}()

