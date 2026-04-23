import { defaultConfig } "Config";
import SystemApi "Apis/SystemApi";
import ZoneApi "Apis/ZoneApi";

persistent actor {
    /// Get device info (returns raw JSON text)
    public func getDeviceInfo() : async Text {
        ignore await* SystemApi.getDeviceInfo(defaultConfig);
        "ok"
    };

    /// Get status for a zone (e.g. "main")
    public func getZoneStatus(zone : Text) : async Text {
        let result = await* ZoneApi.getZoneStatus(defaultConfig, zone);
        switch (result.power) {
            case (?#true_) "on";
            case (?#standby) "standby";
            case null "unknown";
        }
    };
}
