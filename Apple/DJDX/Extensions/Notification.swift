import Foundation

extension Notification.Name {
    static let dataImported = Notification.Name("DJDX.DataImported")
    static let analyticsLayoutReset = Notification.Name("DJDX.AnalyticsLayoutReset")
    static let profileRefreshRequested = Notification.Name("DJDX.ProfileRefreshRequested")
    static let shareCardRequested = Notification.Name("DJDX.ShareCardRequested")
    static let externalDataChanged = Notification.Name("DJDX.ExternalDataChanged")
    static let importSummaryUpdated = Notification.Name("DJDX.ImportSummaryUpdated")
}
