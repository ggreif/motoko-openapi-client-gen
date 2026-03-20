
import { type ArtistObject; JSON = ArtistObject } "./ArtistObject";

import { type ExternalIdObject; JSON = ExternalIdObject } "./ExternalIdObject";

import { type ExternalUrlObject; JSON = ExternalUrlObject } "./ExternalUrlObject";

import { type FollowersObject; JSON = FollowersObject } "./FollowersObject";

import { type ImageObject; JSON = ImageObject } "./ImageObject";

import { type SimplifiedAlbumObject; JSON = SimplifiedAlbumObject } "./SimplifiedAlbumObject";

import { type SimplifiedArtistObject; JSON = SimplifiedArtistObject } "./SimplifiedArtistObject";

import { type TrackObject; JSON = TrackObject } "./TrackObject";

import { type TrackObjectType; JSON = TrackObjectType } "./TrackObjectType";

import { type TrackRestrictionObject; JSON = TrackRestrictionObject } "./TrackRestrictionObject";

// GetUsersTopArtistsAndTracks200ResponseAllOfItemsInner.mo
import Runtime "mo:core/Runtime";

module {
    // User-facing type: discriminated union (oneOf)
    public type GetUsersTopArtistsAndTracks200ResponseAllOfItemsInner = {
        #ArtistObject : ArtistObject;
        #TrackObject : TrackObject;
    };

    // JSON sub-module: everything needed for JSON serialization
    public module JSON {
        // Convert oneOf variant to Text for URL parameters
        public func toText(value : GetUsersTopArtistsAndTracks200ResponseAllOfItemsInner) : Text =
            switch (value) {
                case (#ArtistObject(v)) Runtime.unreachable();
                case (#TrackObject(v)) Runtime.unreachable();
            };

        // JSON-facing Motoko type: mirrors JSON structure
        // Named "JSON" to avoid shadowing the outer GetUsersTopArtistsAndTracks200ResponseAllOfItemsInner type
        public type JSON = {
            #ArtistObject : ArtistObject;
            #TrackObject : TrackObject;
        };

        // Convert User-facing type to JSON-facing Motoko type
        public func toJSON(value : GetUsersTopArtistsAndTracks200ResponseAllOfItemsInner) : JSON =
            switch (value) {
                case (#ArtistObject(v)) #ArtistObject(v);
                case (#TrackObject(v)) #TrackObject(v);
            };

        // Convert JSON-facing Motoko type to User-facing type
        public func fromJSON(json : JSON) : ?GetUsersTopArtistsAndTracks200ResponseAllOfItemsInner =
            switch (json) {
                case (#ArtistObject(v)) ?#ArtistObject(v);
                case (#TrackObject(v)) ?#TrackObject(v);
            };
    }
}
