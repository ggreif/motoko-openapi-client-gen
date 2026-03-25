import Debug "mo:core/Debug";
import Int "mo:core/Int";
import { PowerApi } "../generated/src/Apis/PowerApi";
import { ZoneApi } "../generated/src/Apis/ZoneApi";
import { type SetPowerPowerParameter; JSON = SetPowerPowerParameter } "../generated/src/Models/SetPowerPowerParameter";
import { type SetVolumeVolumeParameter; JSON = SetVolumeVolumeParameter } "../generated/src/Models/SetVolumeVolumeParameter";
import { defaultConfig } "../generated/src/Config";

persistent actor {

    transient let apiConfig = defaultConfig;

    transient let powerApi = PowerApi(apiConfig);
    transient let zoneApi = ZoneApi(apiConfig);

    /// Test sequence: power on, raise volume to 30% in 5-increments, do 10 down steps, do 3 up steps, power off
    public func testYamahaSequence() : async Text {
        Debug.print("Starting Yamaha MusicCast test sequence");

        // 1. Power on
        Debug.print("1. Powering on...");
        let _ = await powerApi.setPower("main", #true_);
        Debug.print("   ✓ Power on");

        // 2. Raise volume from 5 to 30 in increments of 5
        Debug.print("2. Raising volume from 5% to 30%...");
        for (volume in [5, 10, 15, 20, 25, 30].vals()) {
            Debug.print("   Setting volume to " # Int.toText(volume));
            ignore await zoneApi.setVolume("main", #one_of_0(volume), 0);
        };
        Debug.print("   ✓ Volume raised to 30%");

        // 3. Do 10 down steps
        Debug.print("3. Doing 10 down steps...");
        for (i in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10].vals()) {
            Debug.print("   Down step " # Int.toText(i));
            ignore await zoneApi.setVolume("main", #SetVolumeVolumeParameterOneOf(#down), 0);
        };
        Debug.print("   ✓ Completed 10 down steps");

        // 4. Do 3 up steps
        Debug.print("4. Doing 3 up steps...");
        for (i in [1, 2, 3].vals()) {
            Debug.print("   Up step " # Int.toText(i));
            ignore await zoneApi.setVolume("main", #SetVolumeVolumeParameterOneOf(#up), 0);
        };
        Debug.print("   ✓ Completed 3 up steps");

        // 5. Power off (standby)
        Debug.print("5. Powering off...");
        let _ = await powerApi.setPower("main", #standby);
        Debug.print("   ✓ Power off (standby)");

        Debug.print("Test sequence completed successfully!");
        "SUCCESS: Test sequence completed - raised to 30%, 10 down, 3 up, powered off"
    };
}
