
import { type EpisodeBaseReleaseDatePrecision; JSON = EpisodeBaseReleaseDatePrecision } "./EpisodeBaseReleaseDatePrecision";

import { type EpisodeBaseType; JSON = EpisodeBaseType } "./EpisodeBaseType";

import { type EpisodeObject; JSON = EpisodeObject } "./EpisodeObject";

import { type EpisodeRestrictionObject; JSON = EpisodeRestrictionObject } "./EpisodeRestrictionObject";

import { type ExternalIdObject; JSON = ExternalIdObject } "./ExternalIdObject";

import { type ExternalUrlObject; JSON = ExternalUrlObject } "./ExternalUrlObject";

import { type ImageObject; JSON = ImageObject } "./ImageObject";

import { type ResumePointObject; JSON = ResumePointObject } "./ResumePointObject";

import { type SimplifiedAlbumObject; JSON = SimplifiedAlbumObject } "./SimplifiedAlbumObject";

import { type SimplifiedArtistObject; JSON = SimplifiedArtistObject } "./SimplifiedArtistObject";

import { type SimplifiedShowObject; JSON = SimplifiedShowObject } "./SimplifiedShowObject";

import { type TrackObject; JSON = TrackObject } "./TrackObject";

// PlaylistTrackObjectTrack.mo
/// Information about the track or episode.
import Runtime "mo:core/Runtime";

module {
    // User-facing type: discriminated union (oneOf)
    public type PlaylistTrackObjectTrack = {
        #TrackObject : TrackObject;
        #EpisodeObject : EpisodeObject;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // Convert oneOf variant to Text for URL parameters
        public func toText(value : PlaylistTrackObjectTrack) : Text =
            switch (value) {
                case (#TrackObject(v)) Runtime.unreachable();
                case (#EpisodeObject(v)) Runtime.unreachable();
            };

        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer PlaylistTrackObjectTrack type
        public type JSON = {
            #TrackObject : TrackObject;
            #EpisodeObject : EpisodeObject;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : PlaylistTrackObjectTrack) : JSON =
            switch (value) {
                case (#TrackObject(v)) #TrackObject(v);
                case (#EpisodeObject(v)) #EpisodeObject(v);
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?PlaylistTrackObjectTrack =
            switch (json) {
                case (#TrackObject(v)) ?#TrackObject(v);
                case (#EpisodeObject(v)) ?#EpisodeObject(v);
            };
    }
}
