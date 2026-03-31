//
//  XomfitWidgetBundle.swift
//  XomfitWidget
//
//  Created by Dominick Giordano on 3/31/26.
//

import WidgetKit
import SwiftUI

@main
struct XomfitWidgetBundle: WidgetBundle {
    var body: some Widget {
        XomfitWidget()
        XomfitWidgetControl()
        XomfitWidgetLiveActivity()
    }
}
