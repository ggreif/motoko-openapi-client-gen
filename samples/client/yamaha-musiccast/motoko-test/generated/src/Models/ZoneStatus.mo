
import { type ZoneStatusPower; JSON = ZoneStatusPower } "./ZoneStatusPower";

// ZoneStatus.mo

module {
    // User-facing type: what application code uses
    public type ZoneStatus = {
        response_code : ?Int;
        power : ?ZoneStatusPower;
        volume : ?Int;
        max_volume : ?Int;
        mute : ?Bool;
        input : ?Text;
        sound_program : ?Text;
        sleep : ?Int;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer ZoneStatus type
        public type JSON = {
            response_code : ?Int;
            power : ?ZoneStatusPower.JSON;
            volume : ?Int;
            max_volume : ?Int;
            mute : ?Bool;
            input : ?Text;
            sound_program : ?Text;
            sleep : ?Int;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : ZoneStatus) : JSON = { value with
            power = do ? { ZoneStatusPower.toJSON(value.power!) };
        };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?ZoneStatus {
            ?{ json with
                power = do ? { ZoneStatusPower.fromJSON(json.power!)! };
            }
        };
    }
}
