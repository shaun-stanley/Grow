import CoreGraphics

enum CaptureRewardVisualContract {
    static let receiptPadding: CGFloat = 16
    static let receiptHeaderMinHeight: CGFloat = 84
    static let sectionSpacing: CGFloat = 16
    static let metricCellMinHeight: CGFloat = 112
    static let metricCellPadding: CGFloat = 16
    static let metricCellIconSize: CGFloat = 28
    static let metricValueLineHeight: CGFloat = 38
    static let rewardScrollLeadIn: CGFloat = 16

    static let antiSlopChecklist = [
        "Equal metric sizing and padding",
        "Apple native system typography only",
        "Matched receipt header columns",
        "Metric values stay single-line",
        "Metric units stay secondary to the primary number",
        "Clear editorial reading order",
        "No generic translucent card stack",
        "No decorative icon bubbles without semantic purpose"
    ]
}
