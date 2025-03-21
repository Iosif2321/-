/*
    Author: [Håkon]
    [Description]
        Generates a vehicle UID for the garage, up to 10 mil before looping back to 0.
        returns copy so nothing else modifies the UID count

    Arguments:
    0. <nil>

    Return Value:
    <Int> vehicle UID

    Scope: Server
    Environment: unscheduled
    Public: [No]
    Dependencies: HR_Garage_UID

    Example: [] call HR_Garage_fnc_genVehUID;

    License: APL-ND
*/
HR_Garage_UID = (HR_Garage_UID + 1) % 1e7;
HR_Garage_UID
