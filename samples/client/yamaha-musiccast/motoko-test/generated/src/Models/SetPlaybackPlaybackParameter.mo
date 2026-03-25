
// SetPlaybackPlaybackParameter.mo
/// Enum values: #stop, #play, #pause, #previous, #next, #fast_reverse_start, #fast_reverse_end, #fast_forward_start, #fast_forward_end

module {
    // User-facing type: type-safe variants for application code
    public type SetPlaybackPlaybackParameter = {
        #stop;
        #play;
        #pause;
        #previous;
        #next;
        #fast_reverse_start;
        #fast_reverse_end;
        #fast_forward_start;
        #fast_forward_end;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer SetPlaybackPlaybackParameter type
        public type JSON = Text;

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : SetPlaybackPlaybackParameter) : JSON =
            switch (value) {
                case (#stop) "stop";
                case (#play) "play";
                case (#pause) "pause";
                case (#previous) "previous";
                case (#next) "next";
                case (#fast_reverse_start) "fast_reverse_start";
                case (#fast_reverse_end) "fast_reverse_end";
                case (#fast_forward_start) "fast_forward_start";
                case (#fast_forward_end) "fast_forward_end";
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?SetPlaybackPlaybackParameter =
            switch (json) {
                case "stop" ?#stop;
                case "play" ?#play;
                case "pause" ?#pause;
                case "previous" ?#previous;
                case "next" ?#next;
                case "fast_reverse_start" ?#fast_reverse_start;
                case "fast_reverse_end" ?#fast_reverse_end;
                case "fast_forward_start" ?#fast_forward_start;
                case "fast_forward_end" ?#fast_forward_end;
                case _ null;
            };
    }
}
