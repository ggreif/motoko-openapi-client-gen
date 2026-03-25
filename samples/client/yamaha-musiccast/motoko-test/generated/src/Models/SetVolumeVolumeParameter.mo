
import { type SetVolumeVolumeParameterOneOf; JSON = SetVolumeVolumeParameterOneOf } "./SetVolumeVolumeParameterOneOf";

import Int "mo:core/Int";

// SetVolumeVolumeParameter.mo
import Runtime "mo:core/Runtime";

module {
    // User-facing type: discriminated union (oneOf)
    public type SetVolumeVolumeParameter = {
        #one_of_0 : Nat;
        #SetVolumeVolumeParameterOneOf : SetVolumeVolumeParameterOneOf;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // Convert oneOf variant to Text for URL parameters
        public func toText(value : SetVolumeVolumeParameter) : Text =
            switch (value) {
                case (#one_of_0(v)) Int.toText(v);
                case (#SetVolumeVolumeParameterOneOf(v)) SetVolumeVolumeParameterOneOf.toJSON(v);
            };

        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetVolumeVolumeParameter type
        public type JSON = {
            #one_of_0 : Int;
            #SetVolumeVolumeParameterOneOf : SetVolumeVolumeParameterOneOf;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetVolumeVolumeParameter) : JSON =
            switch (value) {
                case (#one_of_0(v)) #one_of_0(v);
                case (#SetVolumeVolumeParameterOneOf(v)) #SetVolumeVolumeParameterOneOf(v);
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetVolumeVolumeParameter =
            switch (json) {
                case (#one_of_0(v)) if (v < 0) null else ?#one_of_0(Int.abs(v));
                case (#SetVolumeVolumeParameterOneOf(v)) ?#SetVolumeVolumeParameterOneOf(v);
            };
    }
}
