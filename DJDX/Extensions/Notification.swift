import Foundation

extension Notification.Name {
    static let dataMigrationCompleted = Notification.Name("DJDX.DataMigrationCompleted")
    static let dataImported = Notification.Name("DJDX.DataImported")
    static let analyticsLayoutReset = Notification.Name("DJDX.AnalyticsLayoutReset")
    static let profileRefreshRequested = Notification.Name("DJDX.ProfileRefreshRequested")
}
