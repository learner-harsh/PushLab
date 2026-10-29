import Foundation

/// Inline documentation shown by the info buttons, following Apple's APNs provider API reference.
enum FieldHelp {
    static let teamId = "The Team ID of your Apple Developer account. You can find it in the Membership section of the developer portal."
    static let keyId = "The 10-character Key ID of the .p8 file. It is shown in Certificates, Identifiers & Profiles → Keys, and is part of the file name (AuthKey_<Key ID>.p8)."
    static let keyFile = "The .p8 private key file generated in the developer portal with the Apple Push Notifications service (APNs) enabled. You can pick the file or paste its content."
    static let certificate = "A .p12 file exported from Keychain Access that contains the APNs certificate and its private key for the app's bundle identifier."
    static let passphrase = "The passphrase you set when exporting the .p12 file. Leave empty if none was set."
    static let keychain = "Push notification identities (certificate + private key) found in your login keychain. Install the APNs certificate from the developer portal into Keychain Access to see it here."
    static let bundleId = "apns-topic. The topic for the notification. In general, the topic is your app's bundle ID, but it may have a suffix based on the push type: .voip, .complication, .pushkit.fileprovider, .location-query, .push-type.liveactivity, or .voip-ptt."
    static let pushType = "apns-push-type. The value of this header must accurately reflect the contents of your notification's payload. Required on watchOS 6 and later; recommended on macOS, iOS, tvOS, and iPadOS."
    static let priority = "apns-priority. The priority of the notification. If you omit this header, APNs sets the priority to 10.\n\n• 10 sends the notification immediately.\n• 5 sends the notification based on power considerations on the user's device.\n• 1 prioritizes the device's power considerations over all other factors and may delay delivery."
    static let expiration = "apns-expiration. The date at which the notification is no longer valid. This value is a UNIX epoch expressed in seconds (UTC).\n\nIf the value is nonzero, APNs stores the notification and tries to deliver it at least once, repeating the attempt as needed until the specified date. If the value is 0, APNs attempts to deliver the notification only once and doesn't store it. Leave empty to omit the header."
    static let collapseId = "apns-collapse-id. An identifier you use to coalesce multiple notifications into a single notification for the user. Typically, each notification request causes a new notification to be displayed on the user's device. When sending the same notification more than once, use the same value in this header to coalesce the requests. The value of this key must not exceed 64 bytes."
    static let notificationId = "apns-id. A canonical UUID that is the unique ID for the notification. If an error occurs when sending the notification, APNs includes this value when reporting the error to your server.\n\nCanonical UUIDs are 32 lowercase hexadecimal digits in the form 8-4-4-4-12, for example 123e4567-e89b-12d3-a456-4266554400a0. If you omit this header, APNs creates a UUID for you and returns it in its response."
    static let environment = "Which APNs server to use. Sandbox (api.sandbox.push.apple.com) is for development builds installed from Xcode; Production (api.push.apple.com) is for TestFlight and App Store builds. Device tokens are specific to an environment."
    static let deviceToken = "The device token for the user, as a hexadecimal string. You can paste several tokens separated by newlines, spaces, or commas; a request is sent for each one."
    static let message = "The JSON payload that you want to send. The payload must be a JSON dictionary and must not exceed 4 KB (5 KB for VoIP pushes). The aps dictionary contains Apple-defined keys; everything else is custom data for your app."
}
