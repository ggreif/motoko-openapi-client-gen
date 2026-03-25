
import { type VolumeParameterOneOf; JSON = VolumeParameterOneOf } "./VolumeParameterOneOf";

import Int "mo:core/Int";

// VolumeParameter.mo
/// Volume control parameter - discriminated union of integer value or direction
import Runtime "mo:core/Runtime";

module {
    // User-facing type: discriminated union (oneOf)
    public type VolumeParameter = {
        #one_of_0 : Nat;
        #VolumeParameterOneOf : VolumeParameterOneOf;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // Convert oneOf variant to Text for URL parameters
        public func toText(value : VolumeParameter) : Text =
            switch (value) {
                case (#one_of_0(v)) Int.toText(v);
                case (#VolumeParameterOneOf(v)) VolumeParameterOneOf.toJSON(v);
            };

        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer VolumeParameter type
        public type JSON = {
            #one_of_0 : Int;
            #VolumeParameterOneOf : VolumeParameterOneOf;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : VolumeParameter) : JSON =
            switch (value) {
                case (#one_of_0(v)) #one_of_0(v);
                case (#VolumeParameterOneOf(v)) #VolumeParameterOneOf(v);
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?VolumeParameter =
            switch (json) {
                case (#one_of_0(v)) if (v < 0) null else ?#one_of_0(Int.abs(v));
                case (#VolumeParameterOneOf(v)) ?#VolumeParameterOneOf(v);
            };
    }
}
