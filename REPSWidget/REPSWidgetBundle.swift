import WidgetKit
import SwiftUI

@main
struct REPSWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutWidget()
        WorkoutLiveActivity()
    }
}
