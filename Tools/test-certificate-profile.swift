import Foundation

@main
struct CertificateProfileTests {
    static func main() throws {
        for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
            for includesDER in [false, true] {
                var profile: [String: Any] = [
                    "AppIDName": "Signing Fixture", "CreationDate": Date(), "Platform": ["iOS"],
                    "DeveloperCertificates": [Data([1, 2, 3])], "ExpirationDate": Date().addingTimeInterval(86400),
                    "Name": "Test Profile", "TeamIdentifier": ["NULLSIGN01"], "TeamName": "NullSign Tests",
                    "TimeToLive": 1, "UUID": UUID().uuidString, "Version": 1,
                    "Entitlements": ["get-task-allow": false]
                ]
                if includesDER { profile["DER-Encoded-Profile"] = Data([4, 5, 6]) }
                let bytes = try PropertyListSerialization.data(fromPropertyList: profile, format: format, options: 0)
                let decoded = try PropertyListDecoder().decode(Certificate.self, from: bytes)
                precondition(decoded.Name == "Test Profile" && decoded.TeamIdentifier == ["NULLSIGN01"])
                precondition(decoded.DeveloperCertificates == [Data([1, 2, 3])])
                precondition((decoded.derEncodedProfile != nil) == includesDER)
            }
        }
        print("Provisioning profile model passed XML/binary profiles with and without DER-Encoded-Profile.")
    }
}
