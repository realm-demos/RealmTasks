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

struct Constants {
    #if DEBUG
    static let syncHost = localIPAddress
    #else
    static let syncHost = "SPECIFY_PRODUCTION_HOST_HERE"
    #endif

    static let syncRealmPath = "realmtasks"
    static let defaultListName = "My Tasks"
    static let defaultListID = "80EB1620-165B-4600-A1B1-D97032FDD9A0"

    static let syncServerURL = NSURL(string: "realm://\(syncHost):7800/private")!
    static let syncAuthURL = NSURL(string: "http://\(syncHost):3000/auth")!

    static let appID = NSBundle.mainBundle().bundleIdentifier!
}
