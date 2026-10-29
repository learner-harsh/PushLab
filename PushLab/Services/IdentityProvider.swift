import Foundation
import Security

struct KeychainIdentity: Identifiable, Hashable {
    let label: String
    let identity: SecIdentity
    let expires: Date?

    var id: String { label }

    static func == (lhs: KeychainIdentity, rhs: KeychainIdentity) -> Bool { lhs.label == rhs.label }
    func hash(into hasher: inout Hasher) { hasher.combine(label) }

    var isExpired: Bool {
        guard let expires else { return false }
        return expires < Date()
    }
}

enum IdentityProvider {
    /// Loads the identity from a PKCS#12 blob. On macOS 15+ nothing is written to the keychain.
    static func identity(fromP12 data: Data, passphrase: String) throws -> SecIdentity {
        var options: [String: Any] = [kSecImportExportPassphrase as String: passphrase]
        if #available(macOS 15.0, *) {
            options[kSecImportToMemoryOnly as String] = true
        }
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)

        if status == errSecSuccess || status == errSecDuplicateItem {
            if let array = items as? [[String: Any]],
               let first = array.first,
               let ref = first[kSecImportItemIdentity as String] {
                let object = ref as CFTypeRef
                if CFGetTypeID(object) == SecIdentityGetTypeID() {
                    return object as! SecIdentity
                }
            }
            if status == errSecDuplicateItem, let found = findDuplicateIdentity(p12: data, passphrase: passphrase) {
                return found
            }
        }
        throw InputError.invalidCertFileOrPassphrase
    }

    /// Older macOS versions import the p12 into the keychain and refuse a second import.
    /// In that case the identity already lives in the keychain, so look for the newest push identity.
    private static func findDuplicateIdentity(p12: Data, passphrase: String) -> SecIdentity? {
        pushIdentities().first?.identity
    }

    /// All identities in the user's keychains whose certificate looks like an APNs certificate.
    static func pushIdentities() -> [KeychainIdentity] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true,
            kSecReturnAttributes as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return [] }

        let markers = ["Push", "VoIP", "Pass Type ID", "Website Push"]
        var found: [KeychainIdentity] = []
        for item in items {
            guard let ref = item[kSecValueRef as String] else { continue }
            let object = ref as CFTypeRef
            guard CFGetTypeID(object) == SecIdentityGetTypeID() else { continue }
            let identity = object as! SecIdentity
            var certificate: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess, let certificate else { continue }
            let summary = (SecCertificateCopySubjectSummary(certificate) as String?) ?? (item[kSecAttrLabel as String] as? String) ?? "Identity"
            guard markers.contains(where: { summary.localizedCaseInsensitiveContains($0) }) else { continue }
            found.append(KeychainIdentity(label: summary, identity: identity, expires: expiry(of: certificate)))
        }
        return found.sorted { $0.label < $1.label }
    }

    static func identity(labelled label: String) throws -> SecIdentity {
        guard let match = pushIdentities().first(where: { $0.label == label }) else {
            throw InputError.noKeychainIdentity
        }
        return match.identity
    }

    static func expiry(of certificate: SecCertificate) -> Date? {
        let keys = [kSecOIDX509V1ValidityNotAfter] as CFArray
        guard let values = SecCertificateCopyValues(certificate, keys, nil) as? [String: Any],
              let entry = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
              let seconds = entry[kSecPropertyKeyValue as String] as? Double else { return nil }
        return Date(timeIntervalSinceReferenceDate: seconds)
    }
}
