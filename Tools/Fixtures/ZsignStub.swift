import Foundation

// Only the engine boundary is replaced. Tests compile the actual app handler.
public enum Zsign {
    public static var succeeds = true
    public static var callbackError: Error?
    public static var callsCompletion = true

    public static func removeDylibs(appExecutable: String, using dylibs: [String]) -> Bool { true }

    public static func sign(
        appPath: String = "", provisionPath: String = "", p12Path: String = "",
        p12Password: String = "", entitlementsPath: String = "", customIdentifier: String = "",
        customName: String = "", customVersion: String = "", adhoc: Bool = false,
        removeProvision: Bool = false, completion: ((Bool, Error?) -> Void)? = nil
    ) -> Bool {
        if callsCompletion { completion?(succeeds, callbackError) }
        return succeeds
    }
}
