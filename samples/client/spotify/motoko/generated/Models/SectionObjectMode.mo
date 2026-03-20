
// SectionObjectMode.mo
/// Indicates the modality (major or minor) of a section, the type of scale from which its melodic content is derived. This field will contain a 0 for \"minor\", a 1 for \"major\", or a -1 for no result. Note that the major key (e.g. C major) could more likely be confused with the minor key at 3 semitones lower (e.g. A minor) as both keys carry the same pitches.
/// Enum values: #minus_1, #_0_, #_1_

module {
    // User-facing type: type-safe variants for application code
    public type SectionObjectMode = {
        #minus_1;
        #_0_;
        #_1_;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SectionObjectMode type
        public type JSON = Float;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SectionObjectMode) : JSON =
            switch (value) {
                case (#minus_1) -1;
                case (#_0_) 0;
                case (#_1_) 1;
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SectionObjectMode =
            switch (json) {
                case (-1) ?#minus_1;
                case (0) ?#_0_;
                case (1) ?#_1_;
                case _ null;
            };
    }
}
