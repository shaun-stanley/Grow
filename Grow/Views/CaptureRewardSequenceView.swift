import SwiftUI

struct CaptureRewardSequenceView: View {
    let reward: CaptureReward

    var body: some View {
        CaptureRewardSequenceContent(reward: reward)
    }
}
