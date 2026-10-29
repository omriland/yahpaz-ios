import Foundation

/// True when the installed build is below the server minimum (hard force update).
public func needsForceUpdate(currentBuild: Int, minBuild: Int) -> Bool {
    currentBuild < minBuild
}
