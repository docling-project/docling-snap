//
//  AVPlayerExtension.swift
//  HuggingSnap
//
//  Created by Cyril Zakka on 2/18/25.
//

import Foundation
import AVKit

extension AVPlayerViewController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.showsPlaybackControls = false
    }
}
