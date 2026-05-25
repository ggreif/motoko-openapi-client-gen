
import { type ZoneStatusPower; JSON = ZoneStatusPower } "./ZoneStatusPower";
import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// ZoneStatus.mo

module {
    /// The required-fields slice of ZoneStatus — what `init` consumes.
    /// Exposed so callers can write `let req : Required = {...}` if they want
    /// to manipulate the required-only payload independently of the full record.
    public type Required = {
    };

    // Optional-fields slice. Private — not part of the consumer surface;
    // it's an internal scaffold so we can express ZoneStatus as an
    // `and`-intersection and keep `init` from listing every optional explicitly.
    type Optional = {
        response_code : ?Int;
        power : ?ZoneStatusPower;
        volume : ?Int;
        max_volume : ?Int;
        mute : ?Bool;
        input : ?Text;
        sound_program : ?Text;
        sleep : ?Int;
    };

    public type ZoneStatus = Required and Optional;

    public module JSON {
        // `init` constructs a ZoneStatus from just its required fields,
        // defaulting all optional fields to `null`. Pair with record-update
        // syntax to layer in selected optionals:
        //   let req = { ZoneStatus.init { …required fields… } with someOpt = ?… };
        // Implementation uses Candid round-trip — Candid record subtyping fills
        // absent optional fields with null. Costs a few cycles per call (init is
        // not on a hot path) but keeps generated code compact regardless of how
        // many optional fields the model has.
        public func init(required : Required) : ZoneStatus {
            let ?res = from_candid(to_candid(required)) : ?ZoneStatus else Runtime.unreachable();
            res
        };

        public func toCandidValue(value : ZoneStatus) : Candid.Candid {
            let buf = List.empty<(Text, Candid.Candid)>();
            switch (value.response_code) {
                case (?v__) List.add(buf, ("response_code", #Int(v__)));
                case null ();
            };
            switch (value.power) {
                case (?v__) List.add(buf, ("power", ZoneStatusPower.toCandidValue(v__)));
                case null ();
            };
            switch (value.volume) {
                case (?v__) List.add(buf, ("volume", #Int(v__)));
                case null ();
            };
            switch (value.max_volume) {
                case (?v__) List.add(buf, ("max_volume", #Int(v__)));
                case null ();
            };
            switch (value.mute) {
                case (?v__) List.add(buf, ("mute", #Bool(v__)));
                case null ();
            };
            switch (value.input) {
                case (?v__) List.add(buf, ("input", #Text(v__)));
                case null ();
            };
            switch (value.sound_program) {
                case (?v__) List.add(buf, ("sound_program", #Text(v__)));
                case null ();
            };
            switch (value.sleep) {
                case (?v__) List.add(buf, ("sleep", #Int(v__)));
                case null ();
            };
            #Record(List.toArray(buf));
        };

        public func fromCandidValue(candid : Candid.Candid) : ?ZoneStatus =
            switch (candid) {
                case (#Record(fields)) {
                    let response_code : ?Int = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "response_code")) {
                        case (?response_code_field) ((switch (response_code_field.1) { case (#Int(i)) ?i; case (#Nat(n)) ?n; case _ null }));
                        case null null;
                    };
                    let power : ?ZoneStatusPower = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "power")) {
                        case (?power_field) (ZoneStatusPower.fromCandidValue(power_field.1));
                        case null null;
                    };
                    let volume : ?Int = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "volume")) {
                        case (?volume_field) ((switch (volume_field.1) { case (#Int(i)) ?i; case (#Nat(n)) ?n; case _ null }));
                        case null null;
                    };
                    let max_volume : ?Int = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "max_volume")) {
                        case (?max_volume_field) ((switch (max_volume_field.1) { case (#Int(i)) ?i; case (#Nat(n)) ?n; case _ null }));
                        case null null;
                    };
                    let mute : ?Bool = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "mute")) {
                        case (?mute_field) ((switch (mute_field.1) { case (#Bool(b)) ?b; case _ null }));
                        case null null;
                    };
                    let input : ?Text = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "input")) {
                        case (?input_field) ((switch (input_field.1) { case (#Text(s)) ?s; case _ null }));
                        case null null;
                    };
                    let sound_program : ?Text = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "sound_program")) {
                        case (?sound_program_field) ((switch (sound_program_field.1) { case (#Text(s)) ?s; case _ null }));
                        case null null;
                    };
                    let sleep : ?Int = switch (Array.find<(Text, Candid.Candid)>(fields, func((k, _) : (Text, Candid.Candid)) : Bool = k == "sleep")) {
                        case (?sleep_field) ((switch (sleep_field.1) { case (#Int(i)) ?i; case (#Nat(n)) ?n; case _ null }));
                        case null null;
                    };
                    ?{
                        response_code;
                        power;
                        volume;
                        max_volume;
                        mute;
                        input;
                        sound_program;
                        sleep;
                    };
                };
                case _ null;
            };
    };

    /// Re-export of `JSON.init` at the outer module level. Three import shapes
    /// all reach the same function:
    ///
    ///   - `import T "...";                                     T.init {…}`     // whole-module
    ///   - `import { type T; JSON = T } "...";                  T.init {…}`     // JSON-alias
    ///   - `import { type T; JSON = T; init = myInit } "...";   myInit {…}`     // explicit rename
    ///
    /// The third form is handy when several models would all be reachable
    /// as `T.init` and you want each bound to a distinct local name.
    public let init = JSON.init;
};
