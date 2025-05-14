disableSerialization;

if (isNil "camList") then {
    camList = [cameraObj1, cameraObj2, cameraObj3];
};

if (isNil "camRotationData") then {
    camRotationData = [];
    {
        camRotationData pushBack [0, 0];
    } forEach camList;
};

activeCam = objNull;
cameraBase = objNull;
currentCamIndex = -1;
nvgEnabled = false;
tfar_relay_agent = objNull;

CAMERA_ROT_STEP = 30;
CAMERA_ROT_FIXED = false;
CAMERA_ROT_X = 0;
CAMERA_ROT_Z = 0;

closeCamMenu = { closeDialog 0 };

openCamView = {
    private _menuDisp = findDisplay 5000;
    if (isNull _menuDisp) exitWith {};
    private _listCtrl = _menuDisp displayCtrl 5100;
    private _selIndex = lbCurSel _listCtrl;
    if (_selIndex < 0) exitWith { hint "Выберите камеру"; };

    currentCamIndex = _selIndex;
    closeDialog 0;
    createDialog "CameraViewDialog";

    private _disp = findDisplay 5001;
    (_disp displayCtrl 5198) ctrlSetText format ["Камера %1", currentCamIndex + 1];
    (_disp displayCtrl 5203) ctrlSetText "ВКЛЮЧИТЬ ПНВ";
    (_disp displayCtrl 5304) ctrlSetText format ["ШАГ: %1°", CAMERA_ROT_STEP];
    (_disp displayCtrl 5305) ctrlSetText "ФИКСАЦИЯ";
    nvgEnabled = false;

    private _obj = camList select currentCamIndex;
    if (!isNull activeCam) then {
        activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
        camDestroy activeCam;
    };
    if (!isNull cameraBase) then { deleteVehicle cameraBase; };

    cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
    cameraBase hideObject true;
    cameraBase setPosASL getPosASL _obj;
    CAMERA_ROT_X = 0;
    CAMERA_ROT_Z = 0;

    private _rot = camRotationData select currentCamIndex;
    CAMERA_ROT_Z = _rot select 0;
    CAMERA_ROT_X = _rot select 1;


    activeCam = "camera" camCreate getPosATL _obj;
    activeCam camSetFov 0.8;
    activeCam camCommit 0;
    activeCam attachTo [cameraBase, [0,0,0]];
    activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
    "CameraFeed" setPiPEffect [0];

    if (isNil "tfar_relay_agent") then {
        tfar_relay_agent = "VirtualMan_F" createVehicleLocal [0,0,0];
        tfar_relay_agent setVariable ["TFAR_forceSpectator", true, true];
    };
    tfar_relay_agent setPosASL getPosASL activeCam;
    player setVariable ["TFAR_spectatorEntity", tfar_relay_agent, true];

    (_disp displayCtrl 5201) ctrlAddEventHandler ["ButtonClick", {[-1] call switchCam}];
    (_disp displayCtrl 5202) ctrlAddEventHandler ["ButtonClick", {[1] call switchCam}];
    (_disp displayCtrl 5203) ctrlAddEventHandler ["ButtonClick", {call toggleNV}];
    (_disp displayCtrl 5204) ctrlAddEventHandler ["ButtonClick", {call disconnectCam}];

    (_disp displayCtrl 5300) ctrlAddEventHandler ["ButtonClick", {call rotateCamLeft}];
    (_disp displayCtrl 5301) ctrlAddEventHandler ["ButtonClick", {call rotateCamRight}];
    (_disp displayCtrl 5302) ctrlAddEventHandler ["ButtonClick", {call rotateCamUp}];
    (_disp displayCtrl 5303) ctrlAddEventHandler ["ButtonClick", {call rotateCamDown}];
    (_disp displayCtrl 5304) ctrlAddEventHandler ["ButtonClick", {call toggleStep}];
    (_disp displayCtrl 5305) ctrlAddEventHandler ["ButtonClick", {call toggleFix}];
};

applyCameraRotation = {
    CAMERA_ROT_X = CAMERA_ROT_X max -89 min 89;
    if (!isNull cameraBase) then {
        cameraBase setVectorDirAndUp [
            [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
            [0, 0, 1]
        ];
    };
};

switchCam = {
    params ["_dir"];
    if (count camList == 0) exitWith {};
    if (!isNull activeCam) then {
        activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
        camDestroy activeCam;
    };
    if (!isNull cameraBase) then { deleteVehicle cameraBase; };

    currentCamIndex = (currentCamIndex + _dir + count camList) mod count camList;
    private _obj = camList select currentCamIndex;

    cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
    cameraBase hideObject true;
    cameraBase setPosASL getPosASL _obj;
    CAMERA_ROT_X = 0;
    CAMERA_ROT_Z = 0;

    activeCam = "camera" camCreate getPosATL _obj;
    activeCam camSetFov 0.8;
    activeCam camCommit 0;
    activeCam attachTo [cameraBase, [0,0,0]];
    activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
    "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];

    if (!isNull tfar_relay_agent) then {
        tfar_relay_agent setPosASL getPosASL activeCam;
    };

    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5198) ctrlSetText format ["Камера %1", currentCamIndex + 1];
        (_disp displayCtrl 5203) ctrlSetText (if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"});
    };

    camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];

};

toggleNV = {
    nvgEnabled = !nvgEnabled;
    "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5203) ctrlSetText (if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"});
    };
};

disconnectCam = {
    if (!isNull activeCam) then {
        activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
        camDestroy activeCam;
    };
    if (!isNull cameraBase) then {
        deleteVehicle cameraBase;
    };
    player setVariable ["TFAR_spectatorEntity", objNull, true];
    closeDialog 0;
};

rotateCamLeft = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_Z = (CAMERA_ROT_Z + CAMERA_ROT_STEP) % 360;
        call applyCameraRotation;
    };
    camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];

};
rotateCamRight = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_Z = (CAMERA_ROT_Z - CAMERA_ROT_STEP + 360) % 360;
        call applyCameraRotation;
    };
    camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];

};
rotateCamUp = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_X = CAMERA_ROT_X + CAMERA_ROT_STEP;
        call applyCameraRotation;
    };
    camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];

};
rotateCamDown = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_X = CAMERA_ROT_X - CAMERA_ROT_STEP;
        call applyCameraRotation;
    };
    camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];

};

toggleStep = {
    switch (CAMERA_ROT_STEP) do {
        case 5:  { CAMERA_ROT_STEP = 15; };
        case 15: { CAMERA_ROT_STEP = 30; };
        case 30: { CAMERA_ROT_STEP = 5; };
    };
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5304) ctrlSetText format ["ШАГ: %1°", CAMERA_ROT_STEP];
    };
};

toggleFix = {
    CAMERA_ROT_FIXED = !CAMERA_ROT_FIXED;
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        (_disp displayCtrl 5305) ctrlSetText (if (CAMERA_ROT_FIXED) then {"РАЗБЛОКА"} else {"ФИКСАЦИЯ"});
    };
};

if (!isNil "terminalObj" && {!isNull terminalObj}) then {
    terminalObj addAction ["Открыть камеры наблюдения", {
        createDialog "CameraMenuDialog";
        private _menuDisp = findDisplay 5000;
        private _listCtrl = _menuDisp displayCtrl 5100;
        lbClear _listCtrl;
        {
            _listCtrl lbAdd format ["Камера %1", _forEachIndex + 1];
        } forEach camList;
    }];
};
