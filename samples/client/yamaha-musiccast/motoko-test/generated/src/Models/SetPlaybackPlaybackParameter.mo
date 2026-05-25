import { Candid } "mo:serde-core";
import Array "mo:core/Array";
import List "mo:core/List";
import Float "mo:core/Float";
import Runtime "mo:core/Runtime";

// SetPlaybackPlaybackParameter.mo
/// Enum values: #stop, #play, #pause, #previous, #next, #fast_reverse_start, #fast_reverse_end, #fast_forward_start, #fast_forward_end

module {
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

    public module JSON {
        public func toCandidValue(value : SetPlaybackPlaybackParameter) : Candid.Candid =
            switch (value) {
                case (#stop) #Text("stop");
                case (#play) #Text("play");
                case (#pause) #Text("pause");
                case (#previous) #Text("previous");
                case (#next) #Text("next");
                case (#fast_reverse_start) #Text("fast_reverse_start");
                case (#fast_reverse_end) #Text("fast_reverse_end");
                case (#fast_forward_start) #Text("fast_forward_start");
                case (#fast_forward_end) #Text("fast_forward_end");
            };

        public func fromCandidValue(candid : Candid.Candid) : ?SetPlaybackPlaybackParameter =
            switch (candid) {
                case (#Text("stop")) ?#stop;
                case (#Text("play")) ?#play;
                case (#Text("pause")) ?#pause;
                case (#Text("previous")) ?#previous;
                case (#Text("next")) ?#next;
                case (#Text("fast_reverse_start")) ?#fast_reverse_start;
                case (#Text("fast_reverse_end")) ?#fast_reverse_end;
                case (#Text("fast_forward_start")) ?#fast_forward_start;
                case (#Text("fast_forward_end")) ?#fast_forward_end;
                case _ null;
            };

        public func toText(value : SetPlaybackPlaybackParameter) : Text =
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
    };
};
