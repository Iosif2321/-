class CfgFunctions {
    class HR_Garage
    {
    //private functions
        class Core
        {
            file = QPATHTOFOLDER(Core);
            class addUser {};
            class broadcast {};
            class confirm {};
            class confirmPlacement {};
            class declairSources {};
            class execForGarageUsers {};
            class genVehUID {};
            class getCatIndex {};
            class onLoad {};
            class onUnload {};
            class reciveBroadcast {};
            class releaseAllVehicles {};
            class reloadCategory {};
            class reloadPreview {};
            class removeFromPool {};
            class removeUser {};
            class requestSelectionChange {};
            class requestVehicle {};
            class selectionChange {};
            class switchCategory {};
            class toggleConfirmBttn {};
            class toggleLock {};
            class updateCamPos {};
            class updateVehicleCount {};
            class validateGarage {};
        };
        class Extras
        {
            file = QPATHTOFOLDER(Extras);
            class findMount {};
            class isAmmoSource {};
            class isFuelSource {};
            class isRepairSource {};
            class reloadExtras {};
            class reloadMounts {};
            class requestMount {};
            class switchExtrasMenu {};
            class switchTexture {};
            class toggleAnim {};
        };
        class Pylons
        {
            file = QPATHTOFOLDER(Pylons);
            class getPylonTurret {};
            class pylonsChanged {};
            class pylonsPresetChanged {};
            class pylonsTurretToggle {};
            class pylonToggleMirror {};
            class reloadPylons {};
            class updatePylons {};
        };
        class StatePreservation
        {
            file = QPATHTOFOLDER(StatePreservation);
            class getAmmoData {};
            class getDamage {};
            class getFuel {};
            class getState {};
            class prepPylons {};
            class setAmmoData {};
            class setDamage {};
            class setFuel {};
            class setState {};
        };

        class Refuel
        {
            file = QPATHTOFOLDER(Refuel);
            class broadcastStateUpdate {};
            class getTotalFuelCargo {};
            class prefix {};
            class reciveStateUpdate {};
            class refuelVehicleFromSources {};
        };

        class Modules {
            file = QPATHTOFOLDER(Modules);
            class initModule_addGarage {};
            class initModule_removeGarage {};
            class initModule_addVehicle {};
            class ZM_confirmSettings {};
        };

    //public functions
        class Public
        {
            file = QPATHTOFOLDER(Public);
            class addVehiclesByClass {};
            class addVehicle {};
            class addVehicleAction {};
            class callbackHandler {};
            class cba_settings {};
            class getSaveData {};
            class initGarage {};
            class initServer {
                preInit = 1;
            };
            class loadSaveData {};
            class removeGarage {};
            class toggleGarageAccess {};
        };
    };
};
