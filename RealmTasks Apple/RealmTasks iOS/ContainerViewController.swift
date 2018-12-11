////////////////////////////////////////////////////////////////////////////
//
// Copyright 2016-2017 Realm Inc.
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

import Cartography
import RealmSwift
import UIKit

class ContainerViewController: UIViewController {
    @IBOutlet private var titleBar: UIView!
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var titleHeightConstraint: NSLayoutConstraint?
    @IBOutlet var containerView: UIView!

    override var title: String? {
        didSet {
            if let title = title {
                titleLabel.text = title
            }
            titleHeightConstraint?.constant = (title != nil) ? 20 : 0
            UIView.animate(withDuration: 0.2) {
                self.titleLabel.alpha = (self.title != nil) ? 1 : 0
                self.titleBar.layoutIfNeeded()
            }
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChildVC()
        setupTitleBar()
    }

    private func addChildVC() {
        let firstList = try! Realm().objects(TaskList.self).first!
        UIView.performWithoutAnimation {
            title = firstList.text
        }

        let vc = ViewController(parent: firstList, colors: UIColor.taskColors())
        addChildViewController(vc)
        containerView.addSubview(vc.view)
        vc.didMove(toParentViewController: self)
    }

    private func setupTitleBar() {
        titleLabel.font = .boldSystemFont(ofSize: 13)
    }
}
