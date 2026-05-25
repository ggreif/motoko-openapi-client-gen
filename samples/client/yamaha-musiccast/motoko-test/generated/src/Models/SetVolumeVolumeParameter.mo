
import { type SetVolumeVolumeParameterOneOf; JSON = SetVolumeVolumeParameterOneOf } "./SetVolumeVolumeParameterOneOf";
import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";
import Int "mo:core/Int";

// SetVolumeVolumeParameter.mo
// Generic oneOf (no discriminator, no flatten) — wire form is `{"#tag": ...}`.

module {
    public type SetVolumeVolumeParameter = {
        #one_of_0 : Nat;
        #SetVolumeVolumeParameterOneOf : SetVolumeVolumeParameterOneOf;
    };

    public module JSON {
        // Generic oneOf is rare on the surfaces we care about (chat / tweet
        // bodies use discriminator-oneOf or string-flatten). The branches here
        // can mix primitives, parametrised types, and arrays — none of which
        // dispatch cleanly via `OneOf&lt;integer,setVolumeVolumeParameterOneOf&gt;.toCandidValue(v)` (Text isn't a
        // module; `Map<K,V>` and `[[Int]]` aren't dottable identifiers). To
        // keep the file type-checking (so `mops publish` can extract docs),
        // stub all three converters with `Runtime.unreachable()`. Real
        // implementations are a follow-up — primitive dispatch + recursive
        // partial reuse for arrays/maps inside oneOf branches.
        public func toText(_value : SetVolumeVolumeParameter) : Text = Runtime.unreachable();

        public func toCandidValue(_value : SetVolumeVolumeParameter) : Candid.Candid = Runtime.unreachable();

        public func fromCandidValue(_candid : Candid.Candid) : ?SetVolumeVolumeParameter = Runtime.unreachable();
    };
};
