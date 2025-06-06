disableSerialization;

// Инициализация массива камер, если он не определён
if (isNil "camList") then {
    camList = [];

    // Добавляем камеру без индекса
    if (!isNil "cameraObj") then {
        camList pushBack cameraObj;
    };

    // Перебираем cameraObj_1, cameraObj_2, ...
    private _i = 1;
    while {
        private _varName = format ["cameraObj_%1", _i];
        private _cam = missionNamespace getVariable [_varName, objNull];
        !isNull _cam
    } do {
        private _varName = format ["cameraObj_%1", _i];
        private _cam = missionNamespace getVariable [_varName, objNull];
        camList pushBack _cam;
        _i = _i + 1;
    };
    diag_log format ["Initialized camList with %1 cameras", count camList];
};

// Инициализация данных о повороте камер
if (isNil "camRotationData") then {
    camRotationData = [];
    {
        camRotationData pushBack [0, 0];
    } forEach camList;
};

// Инициализация переменных для мультикамерного режима
if (isNil "multiCamMode") then {
    multiCamMode = false;
};

if (isNil "multiCamCount") then {
    multiCamCount = 4; // По умолчанию 4 камеры в мульти-режиме
};

// Инициализация массивов активных камер и базовых объектов
if (isNil "activeMultiCams") then {
    activeMultiCams = [];
};

if (isNil "multiCameraBase") then {
    multiCameraBase = [];
};

// Массив индексов камер, отображаемых в мультирежиме
if (isNil "multiCamIndexes") then {
    multiCamIndexes = [];
};

// Массив состояния ПНВ для каждого слота в мультирежиме
if (isNil "nvgEnabledMulti") then {
    nvgEnabledMulti = [];
};

// Глобальные переменные
activeCam = objNull;
cameraBase = objNull;
currentCamIndex = -1;
nvgEnabled = false;
tfar_relay_agent = objNull;
tfarEH = -1;

createCamLight = {
    params ["_base"];
    private _l = "#lightpoint" createVehicleLocal getPosATL _base;
    _l setLightBrightness 5;
    _l setLightAmbient [1,1,1];
    _l setLightColor [1,1,1];
    _l setLightAttenuation [0,0,0,0.1];
    _l attachTo [_base,[0,0,2]];
    _l
};

setupTfarRelay = {
    params ["_base"];
    if (isNil "tfar_relay_agent") then {
        tfar_relay_agent = "VirtualMan_F" createVehicleLocal [0,0,0];
        tfar_relay_agent setVariable ["TFAR_forceSpectator",true,true];
    };
    tfar_relay_agent attachTo [_base,[0,0,0]];
    player setVariable ["TFAR_spectatorEntity",tfar_relay_agent,true];
    if (tfarEH == -1) then {
        tfarEH = addMissionEventHandler ["EachFrame",{
            if (!isNull tfar_relay_agent) then {
                if (!isNull activeCam) then {tfar_relay_agent setPosASL getPosASL activeCam} else {
                    if (multiCamMode && {selectedMultiCamIndex < count multiCameraBase}) then {
                        tfar_relay_agent setPosASL getPosASL (multiCameraBase select selectedMultiCamIndex)
                    };
                };
            };
        }];
    };
};

stopTfarRelay = {
    if (tfarEH != -1) then {removeMissionEventHandler ["EachFrame",tfarEH]; tfarEH = -1};
    player setVariable ["TFAR_spectatorEntity",objNull,true];
    if (!isNull tfar_relay_agent) then {deleteVehicle tfar_relay_agent; tfar_relay_agent = objNull};
};

// Переменные для источников света (чтобы можно было удалять их при отключении)
if (isNil "activeLight") then {
    activeLight = objNull;
};
if (isNil "activeMultiLights") then {
    activeMultiLights = [];
};

// Константы для вращения камеры
CAMERA_ROT_STEP = 30;
CAMERA_ROT_FIXED = false;
CAMERA_ROT_X = 0;
CAMERA_ROT_Z = 0;

// Выбранная камера в мультирежиме (для управления)
selectedMultiCamIndex = 0;

// Переменная для хранения эффекта пост-обработки
if (isNil "ppEffectBrightness") then {
    ppEffectBrightness = ppEffectCreate ["ColorCorrections", 1501];
    ppEffectBrightness ppEffectEnable true;
    // Настройки яркости и контраста
    ppEffectBrightness ppEffectAdjust [1, 1.2, 0, [0, 0, 0, 0], [1, 1, 1, 1], [0.3, 0.3, 0.3, 0]];
    ppEffectBrightness ppEffectCommit 0;
    diag_log "Initialized post-processing effect for brightness and contrast";
};

// Переменная для управления таймером подсветки
if (isNil "highlightTimer") then {
    highlightTimer = -1;
};

// Закрыть меню камеры
closeCamMenu = { closeDialog 0 };

// Открыть просмотр выбранной камеры
openCamView = {
    private _menuDisp = findDisplay 5000;
    if (isNull _menuDisp) exitWith { diag_log "openCamView ERROR: Display 5000 not found"; };
    private _listCtrl = _menuDisp displayCtrl 5100;
    if (isNull _listCtrl) exitWith { diag_log "openCamView ERROR: List control 5100 not found"; };
    private _selIndex = lbCurSel _listCtrl;
    if (_selIndex < 0) exitWith { hint "Выберите камеру"; diag_log "openCamView: No camera selected"; };

    currentCamIndex = _selIndex;
    closeDialog 0;
    createDialog "CameraViewDialog";

    private _disp = findDisplay 5001;
    if (isNull _disp) exitWith { diag_log "openCamView ERROR: Dialog 5001 not found"; };

    // Установка текста кнопок
    private _ctrl5198 = _disp displayCtrl 5198;
    if (!isNull _ctrl5198) then {
        _ctrl5198 ctrlSetText format ["Камера %1", currentCamIndex + 1];
        _ctrl5198 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5198 not found";
    };

    private _ctrl5203 = _disp displayCtrl 5203;
    if (!isNull _ctrl5203) then {
        _ctrl5203 ctrlSetText "ВКЛЮЧИТЬ ПНВ"; // ПНВ выключено по умолчанию
        _ctrl5203 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5203 not found";
    };

    private _ctrl5304 = _disp displayCtrl 5304;
    if (!isNull _ctrl5304) then {
        _ctrl5304 ctrlSetText format ["ШАГ: %1°", CAMERA_ROT_STEP];
        _ctrl5304 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5304 not found";
    };

    private _ctrl5305 = _disp displayCtrl 5305;
    if (!isNull _ctrl5305) then {
        _ctrl5305 ctrlSetText "ФИКСАЦИЯ";
        _ctrl5305 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5305 not found";
    };

    private _ctrl5306 = _disp displayCtrl 5306;
    if (!isNull _ctrl5306) then {
        _ctrl5306 ctrlSetText "МУЛЬТИ-РЕЖИМ";
        _ctrl5306 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5306 not found";
    };

    nvgEnabled = false; // ПНВ выключено по умолчанию
    multiCamMode = false;

    private _obj = camList select currentCamIndex;
    if (isNull _obj) exitWith {
        hint "Ошибка: Камера не найдена";
        diag_log format ["openCamView ERROR: Camera object at index %1 is null", currentCamIndex];
    };

    // Отладка времени и позиции
    diag_log format ["Game time: %1 hours, Camera position: %2", daytime, getPosATL _obj];

    // Временное изменение времени суток (для теста)
    setDate [2025, 5, 17, 12, 46]; // Устанавливаем текущее время 12:46 PM CEST

    if (!isNull activeCam) then {
        activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
        camDestroy activeCam;
    };
    if (!isNull cameraBase) then { deleteVehicle cameraBase; };
    if (!isNull activeLight) then { deleteVehicle activeLight; };

    cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
    cameraBase hideObject true;
    cameraBase setPosASL getPosASL _obj;
    CAMERA_ROT_X = 0;
    CAMERA_ROT_Z = 0;

    private _rot = camRotationData select currentCamIndex;
    CAMERA_ROT_Z = _rot select 0;
    CAMERA_ROT_X = _rot select 1;

    activeCam = "camera" camCreate getPosATL _obj;
    if (isNull activeCam) exitWith {
        hint "Ошибка: Не удалось создать камеру";
        diag_log "openCamView ERROR: Failed to create activeCam";
    };
    activeCam camSetFov 0.8;
    activeCam camCommit 0;
    activeCam attachTo [cameraBase, [0,0,0]];
    activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
    "CameraFeed" setPiPEffect [0]; // ПНВ выключено по умолчанию
    diag_log format ["Created activeCam at %1", getPosATL _obj];

    activeLight = [cameraBase] call createCamLight;
    [cameraBase] call setupTfarRelay;

    // Настройка отображения камеры
    private _borderSize = 0.01;
    private _camX = safezoneX + _borderSize;
    private _camY = safezoneY + 0.12; // Увеличено пространство для кнопок сверху
    private _camW = safezoneW - (2 * _borderSize);
    private _camH = safezoneH - 0.14; // Уменьшено, чтобы освободить место для кнопок

    private _camCtrl = _disp displayCtrl 5200;
    if (isNull _camCtrl) exitWith {
        diag_log "openCamView ERROR: Camera control 5200 not found";
    };
    _camCtrl ctrlSetPosition [_camX, _camY, _camW, _camH];
    _camCtrl ctrlSetText "#(argb,512,512,1)r2t(CameraFeed,1.777)";
    _camCtrl ctrlShow true;
    _camCtrl ctrlCommit 0;
    diag_log "Set camera texture with fixed aspect ratio 1.777";

    // Расположение кнопок управления с увеличенным вертикальным отступом и шириной
    private _buttonY = safezoneY + 0.02; // Начальная Y-координата
    private _buttonH = 0.04; // Высота кнопки
    private _buttonSpacing = 0.05; // Вертикальный интервал между кнопками
    private _buttonGap = 0.01; // Горизонтальный зазор между кнопками

    // Первая строка кнопок
    private _ctrl5201 = _disp displayCtrl 5201;
    if (!isNull _ctrl5201) then {
        _ctrl5201 ctrlSetPosition [safezoneX + 0.01, _buttonY, 0.14, _buttonH];
        _ctrl5201 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5201 not found";
    };

    private _ctrl5202 = _disp displayCtrl 5202;
    if (!isNull _ctrl5202) then {
        _ctrl5202 ctrlSetPosition [safezoneX + 0.16 + _buttonGap, _buttonY, 0.14, _buttonH];
        _ctrl5202 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5202 not found";
    };

    private _ctrl5203 = _disp displayCtrl 5203;
    if (!isNull _ctrl5203) then {
        _ctrl5203 ctrlSetPosition [safezoneX + 0.32 + 2 * _buttonGap, _buttonY, 0.25, _buttonH];
        _ctrl5203 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5203 not found";
    };

    private _ctrl5204 = _disp displayCtrl 5204;
    if (!isNull _ctrl5204) then {
        _ctrl5204 ctrlSetPosition [safezoneX + 0.58 + 3 * _buttonGap, _buttonY, 0.20, _buttonH]; // Увеличиваем ширину кнопки "ОТКЛЮЧИТЬ"
        _ctrl5204 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5204 not found";
    };

    _buttonY = _buttonY + _buttonSpacing;

    // Вторая строка кнопок
    private _ctrl5300 = _disp displayCtrl 5300;
    if (!isNull _ctrl5300) then {
        _ctrl5300 ctrlSetPosition [safezoneX + 0.01, _buttonY, 0.14, _buttonH];
        _ctrl5300 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5300 not found";
    };

    private _ctrl5301 = _disp displayCtrl 5301;
    if (!isNull _ctrl5301) then {
        _ctrl5301 ctrlSetPosition [safezoneX + 0.16 + _buttonGap, _buttonY, 0.14, _buttonH];
        _ctrl5301 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5301 not found";
    };

    private _ctrl5302 = _disp displayCtrl 5302;
    if (!isNull _ctrl5302) then {
        _ctrl5302 ctrlSetPosition [safezoneX + 0.32 + 2 * _buttonGap, _buttonY, 0.14, _buttonH];
        _ctrl5302 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5302 not found";
    };

    private _ctrl5303 = _disp displayCtrl 5303;
    if (!isNull _ctrl5303) then {
        _ctrl5303 ctrlSetPosition [safezoneX + 0.47 + 3 * _buttonGap, _buttonY, 0.14, _buttonH];
        _ctrl5303 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5303 not found";
    };

    _buttonY = _buttonY + _buttonSpacing;

    // Третья строка кнопок (сдвигаем левее)
    private _ctrl5304 = _disp displayCtrl 5304;
    if (!isNull _ctrl5304) then {
        _ctrl5304 ctrlSetPosition [safezoneX + 0.01, _buttonY, 0.22, _buttonH]; // Сдвигаем левее
        _ctrl5304 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5304 not found";
    };

    private _ctrl5305 = _disp displayCtrl 5305;
    if (!isNull _ctrl5305) then {
        _ctrl5305 ctrlSetPosition [safezoneX + 0.24 + _buttonGap, _buttonY, 0.22, _buttonH]; // Сдвигаем левее
        _ctrl5305 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5305 not found";
    };

    private _ctrl5306 = _disp displayCtrl 5306;
    if (!isNull _ctrl5306) then {
        _ctrl5306 ctrlSetPosition [safezoneX + 0.47 + 2 * _buttonGap, _buttonY, 0.25, _buttonH]; // Сдвигаем левее
        _ctrl5306 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5306 not found";
    };

    _buttonY = _buttonY + _buttonSpacing;

    // Четвёртая строка кнопок (для мульти-режима)
    private _ctrl5307 = _disp displayCtrl 5307;
    if (!isNull _ctrl5307) then {
        _ctrl5307 ctrlSetPosition [safezoneX + 0.01, _buttonY, 0.25, _buttonH];
        _ctrl5307 ctrlShow false;
        _ctrl5307 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5307 not found";
    };

    private _ctrl5308 = _disp displayCtrl 5308;
    if (!isNull _ctrl5308) then {
        _ctrl5308 ctrlSetPosition [safezoneX + 0.27 + _buttonGap, _buttonY, 0.25, _buttonH];
        _ctrl5308 ctrlShow false;
        _ctrl5308 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5308 not found";
    };

    private _ctrl5309 = _disp displayCtrl 5309;
    if (!isNull _ctrl5309) then {
        _ctrl5309 ctrlSetPosition [safezoneX + 0.53 + 2 * _buttonGap, _buttonY, 0.25, _buttonH];
        _ctrl5309 ctrlShow false;
        _ctrl5309 ctrlCommit 0;
    } else {
        diag_log "openCamView ERROR: Control 5309 not found";
    };

    // Показываем кнопки
    {
        if (!isNull _x) then {
            _x ctrlShow true;
        };
    } forEach [
        _disp displayCtrl 5201,
        _disp displayCtrl 5202,
        _disp displayCtrl 5203,
        _disp displayCtrl 5204,
        _disp displayCtrl 5300,
        _disp displayCtrl 5301,
        _disp displayCtrl 5302,
        _disp displayCtrl 5303,
        _disp displayCtrl 5304,
        _disp displayCtrl 5305,
        _disp displayCtrl 5306
    ];

    // Добавление обработчиков событий
    private _ctrl5201 = _disp displayCtrl 5201;
    if (!isNull _ctrl5201) then {
        _ctrl5201 ctrlAddEventHandler ["ButtonClick", {[-1] call switchCam}];
    };

    private _ctrl5202 = _disp displayCtrl 5202;
    if (!isNull _ctrl5202) then {
        _ctrl5202 ctrlAddEventHandler ["ButtonClick", {[1] call switchCam}];
    };

    private _ctrl5203 = _disp displayCtrl 5203;
    if (!isNull _ctrl5203) then {
        _ctrl5203 ctrlAddEventHandler ["ButtonClick", {call toggleNV}];
    };

    private _ctrl5204 = _disp displayCtrl 5204;
    if (!isNull _ctrl5204) then {
        _ctrl5204 ctrlAddEventHandler ["ButtonClick", {call disconnectCam}];
    };

    private _ctrl5300 = _disp displayCtrl 5300;
    if (!isNull _ctrl5300) then {
        _ctrl5300 ctrlAddEventHandler ["ButtonClick", {call rotateCamLeft}];
    };

    private _ctrl5301 = _disp displayCtrl 5301;
    if (!isNull _ctrl5301) then {
        _ctrl5301 ctrlAddEventHandler ["ButtonClick", {call rotateCamRight}];
    };

    private _ctrl5302 = _disp displayCtrl 5302;
    if (!isNull _ctrl5302) then {
        _ctrl5302 ctrlAddEventHandler ["ButtonClick", {call rotateCamUp}];
    };

    private _ctrl5303 = _disp displayCtrl 5303;
    if (!isNull _ctrl5303) then {
        _ctrl5303 ctrlAddEventHandler ["ButtonClick", {call rotateCamDown}];
    };

    private _ctrl5304 = _disp displayCtrl 5304;
    if (!isNull _ctrl5304) then {
        _ctrl5304 ctrlAddEventHandler ["ButtonClick", {call toggleStep}];
    };

    private _ctrl5305 = _disp displayCtrl 5305;
    if (!isNull _ctrl5305) then {
        _ctrl5305 ctrlAddEventHandler ["ButtonClick", {call toggleFix}];
    };

    private _ctrl5306 = _disp displayCtrl 5306;
    if (!isNull _ctrl5306) then {
        _ctrl5306 ctrlAddEventHandler ["ButtonClick", {call toggleMultiCamMode}];
    };

    private _ctrl5307 = _disp displayCtrl 5307;
    if (!isNull _ctrl5307) then {
        _ctrl5307 ctrlAddEventHandler ["ButtonClick", {call cycleMultiCamCount}];
    };

    private _ctrl5308 = _disp displayCtrl 5308;
    if (!isNull _ctrl5308) then {
        _ctrl5308 ctrlAddEventHandler ["ButtonClick", {[-1] call switchSelectedMultiCamSlot}];
    };

    private _ctrl5309 = _disp displayCtrl 5309;
    if (!isNull _ctrl5309) then {
        _ctrl5309 ctrlAddEventHandler ["ButtonClick", {[1] call switchSelectedMultiCamSlot}];
    };
};

// Применить вращение камеры
applyCameraRotation = {
    params [["_camIndex", currentCamIndex]];

    CAMERA_ROT_X = CAMERA_ROT_X max -89 min 89;
    CAMERA_ROT_Z = CAMERA_ROT_Z % 360;

    diag_log format ["applyCameraRotation - camIndex: %1, multiCamMode: %2, CAMERA_ROT_X: %3, CAMERA_ROT_Z: %4", _camIndex, multiCamMode, CAMERA_ROT_X, CAMERA_ROT_Z];

    if (multiCamMode) then {
        if (_camIndex >= 0 && _camIndex < count multiCameraBase) then {
            private _base = multiCameraBase select _camIndex;
            if (!isNull _base) then {
                _base setVectorDirAndUp [
                    [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
                    [0, 0, 1]
                ];
            } else {
                diag_log format ["applyCameraRotation ERROR: multiCameraBase at index %1 is null", _camIndex];
            };
        } else {
            diag_log format ["applyCameraRotation ERROR: Invalid _camIndex %1 for multiCameraBase (count: %2)", _camIndex, count multiCameraBase];
        };
    } else {
        if (!isNull cameraBase) then {
            cameraBase setVectorDirAndUp [
                [cos CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_Z * cos CAMERA_ROT_X, sin CAMERA_ROT_X],
                [0, 0, 1]
            ];
        } else {
            diag_log "applyCameraRotation ERROR: cameraBase is null";
        };
    };
};

// Переключение выбранной камеры в мультирежиме
switchSelectedMultiCam = {
    params ["_dir"];
    if (count camList == 0) exitWith {};

    if (multiCamMode) then {
        private _currentSlotCamIndex = multiCamIndexes select selectedMultiCamIndex;
        private _newCamIndex = (_currentSlotCamIndex + _dir + count camList) mod count camList;
        multiCamIndexes set [selectedMultiCamIndex, _newCamIndex];
        [selectedMultiCamIndex] call updateMultiCamSlot;

        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            private _slotTextCtrl = _disp displayCtrl (5600 + selectedMultiCamIndex);
            if (!isNull _slotTextCtrl) then {
                _slotTextCtrl ctrlSetText format ["Камера %1", _newCamIndex + 1];
                _slotTextCtrl ctrlCommit 0;
            };
            
            private _ctrl5198 = _disp displayCtrl 5198;
            if (!isNull _ctrl5198) then {
                _ctrl5198 ctrlSetText format ["Мульти-режим - Слот %1 - Камера %2", 
                    selectedMultiCamIndex + 1, _newCamIndex + 1];
                _ctrl5198 ctrlCommit 0;
            };
        };
        
        private _rot = camRotationData select _newCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
    };
};

// Переключение выбранного слота в мультирежиме
switchSelectedMultiCamSlot = {
    params ["_dir"];
    if (!multiCamMode) exitWith {};

    // Удаляем предыдущий таймер подсветки, если он существует
    if (highlightTimer != -1) then {
        removeMissionEventHandler ["EachFrame", highlightTimer];
        highlightTimer = -1;
    };

    private _newSlotIndex = (selectedMultiCamIndex + _dir + multiCamCount) mod multiCamCount;
    selectedMultiCamIndex = _newSlotIndex;

    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        {
            private _borderCtrl = _disp displayCtrl (5500 + _forEachIndex);
            if (!isNull _borderCtrl) then {
                if (_forEachIndex == selectedMultiCamIndex) then {
                    _borderCtrl ctrlSetTextColor [1, 0, 0, 1];
                    _borderCtrl ctrlSetBackgroundColor [1, 0, 0, 0.3];
                    _borderCtrl ctrlCommit 0;
                    // Запускаем таймер для убирания подсветки через 3 секунды
                    private _endTime = diag_tickTime + 3;
                    highlightTimer = addMissionEventHandler ["EachFrame", {
                        if (diag_tickTime >= _this # 1) then {
                            private _ctrl = _this # 0;
                            if (!isNull _ctrl) then {
                                _ctrl ctrlSetTextColor [1, 1, 1, 0];
                                _ctrl ctrlSetBackgroundColor [0, 0, 0, 0];
                                _ctrl ctrlCommit 0;
                            };
                            removeMissionEventHandler ["EachFrame", _this # 2];
                        };
                    }, [_borderCtrl, _endTime, highlightTimer]];
                } else {
                    _borderCtrl ctrlSetTextColor [1, 1, 1, 0];
                    _borderCtrl ctrlSetBackgroundColor [0, 0, 0, 0];
                    _borderCtrl ctrlCommit 0;
                };
            };
        } forEach [0, 1, 2, 3, 4, 5, 6, 7]; // Проверяем все возможные слоты

        private _camIndex = multiCamIndexes select selectedMultiCamIndex;
        private _ctrl5198 = _disp displayCtrl 5198;
        if (!isNull _ctrl5198) then {
            _ctrl5198 ctrlSetText format ["Мульти-режим - Слот %1 - Камера %2", 
                selectedMultiCamIndex + 1, _camIndex + 1];
            _ctrl5198 ctrlCommit 0;
        };

        private _ctrl5203 = _disp displayCtrl 5203;
        if (!isNull _ctrl5203) then {
            private _nvgText = if (nvgEnabledMulti select selectedMultiCamIndex) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"};
            _ctrl5203 ctrlSetText _nvgText;
            _ctrl5203 ctrlCommit 0;
        };

        private _rot = camRotationData select _camIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
        [multiCameraBase select selectedMultiCamIndex] call setupTfarRelay;
    };
};

// Обновить камеру в выбранном слоте мультирежима
updateMultiCamSlot = {
    params ["_slotIndex"];

    if (_slotIndex < 0 || _slotIndex >= count activeMultiCams) exitWith {};

    private _camIndex = multiCamIndexes select _slotIndex;
    private _obj = camList select _camIndex;

    if (_slotIndex < count multiCameraBase) then {
        private _base = multiCameraBase select _slotIndex;
        if (!isNull _base) then {
            _base setPosASL getPosASL _obj;
            
            private _rot = camRotationData select _camIndex;
            _base setVectorDirAndUp [
                [cos (_rot select 0) * cos (_rot select 1), sin (_rot select 0) * cos (_rot select 1), sin (_rot select 1)],
                [0, 0, 1]
            ];
        };
    };

    if (_slotIndex < count activeMultiCams) then {
        private _cam = activeMultiCams select _slotIndex;
        if (!isNull _cam) then {
            _cam cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _slotIndex]];
            camDestroy _cam;
        };

        // Удаляем старый источник света, если он есть
        if (_slotIndex < count activeMultiLights) then {
            private _oldLight = activeMultiLights select _slotIndex;
            if (!isNull _oldLight) then {
                deleteVehicle _oldLight;
            };
        };
        
        private _newCam = "camera" camCreate getPosATL _obj;
        _newCam camSetFov 0.8;
        _newCam camCommit 0;
        _newCam attachTo [multiCameraBase select _slotIndex, [0,0,0]];
        _newCam cameraEffect ["Internal", "Back", format ["MultiCamFeed_%1", _slotIndex]];
        format ["MultiCamFeed_%1", _slotIndex] setPiPEffect [0]; // ПНВ выключено по умолчанию
        activeMultiCams set [_slotIndex, _newCam];

        // Добавляем новый источник света
        private _light = [multiCameraBase select _slotIndex] call createCamLight;
        activeMultiLights set [_slotIndex, _light];
        diag_log format ["Added enhanced light to multi-camera %1", _slotIndex];
    };
};

// Переключение между камерами
switchCam = {
    params ["_dir"];
    if (count camList == 0) exitWith {};

    if (multiCamMode) then {
        [_dir] call switchSelectedMultiCam;
    } else {
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then { deleteVehicle cameraBase; };
        if (!isNull activeLight) then { deleteVehicle activeLight; };

        currentCamIndex = (currentCamIndex + _dir + count camList) mod count camList;
        private _obj = camList select currentCamIndex;

        cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
        cameraBase hideObject true;
        cameraBase setPosASL getPosASL _obj;
        
        private _rot = camRotationData select currentCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;

        activeCam = "camera" camCreate getPosATL _obj;
        if (isNull activeCam) exitWith {
            diag_log "switchCam ERROR: Failed to create activeCam";
        };
        activeCam camSetFov 0.8;
        activeCam camCommit 0;
        activeCam attachTo [cameraBase, [0,0,0]];
        activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
        "CameraFeed" setPiPEffect [0]; // ПНВ выключено по умолчанию

        activeLight = [cameraBase] call createCamLight;
        [cameraBase] call setupTfarRelay;

        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            private _ctrl5198 = _disp displayCtrl 5198;
            if (!isNull _ctrl5198) then {
                _ctrl5198 ctrlSetText format ["Камера %1", currentCamIndex + 1];
                _ctrl5198 ctrlCommit 0;
            };

            private _ctrl5203 = _disp displayCtrl 5203;
            if (!isNull _ctrl5203) then {
                _ctrl5203 ctrlSetText "ВКЛЮЧИТЬ ПНВ";
                _ctrl5203 ctrlCommit 0;
            };
        };
        
        [currentCamIndex] call applyCameraRotation;
    };
};

// Переключение ПНВ для камеры
toggleNV = {
    if (multiCamMode) then {
        private _slotIndex = selectedMultiCamIndex;
        private _enabled = !(nvgEnabledMulti select _slotIndex);
        nvgEnabledMulti set [_slotIndex, _enabled];
        private _feedName = format ["MultiCamFeed_%1", _slotIndex];
        _feedName setPiPEffect [if (_enabled) then {1} else {0}];
    } else {
        nvgEnabled = !nvgEnabled;
        "CameraFeed" setPiPEffect [if (nvgEnabled) then {1} else {0}];
    };
    
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        private _ctrl5203 = _disp displayCtrl 5203;
        if (!isNull _ctrl5203) then {
            _ctrl5203 ctrlSetText (if (multiCamMode) then {
                if (nvgEnabledMulti select selectedMultiCamIndex) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"}
            } else {
                if (nvgEnabled) then {"ВЫКЛЮЧИТЬ ПНВ"} else {"ВКЛЮЧИТЬ ПНВ"}
            });
            _ctrl5203 ctrlCommit 0;
        };
    };
    diag_log format ["NVG toggled: multiCamMode=%1, nvgEnabled=%2, nvgEnabledMulti=%3", multiCamMode, nvgEnabled, nvgEnabledMulti];
};

// Отключение от камеры
disconnectCam = {
    // Удаляем таймер подсветки, если он существует
    if (highlightTimer != -1) then {
        removeMissionEventHandler ["EachFrame", highlightTimer];
        highlightTimer = -1;
    };

    if (multiCamMode) then {
        {
            if (!isNull _x) then {
                _x cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _forEachIndex]];
                camDestroy _x;
            };
        } forEach activeMultiCams;
        
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach multiCameraBase;

        // Удаляем источники света
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach activeMultiLights;
        
        activeMultiCams = [];
        multiCameraBase = [];
        multiCamIndexes = [];
        nvgEnabledMulti = [];
        activeMultiLights = [];
    } else {
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then { deleteVehicle cameraBase; };
        if (!isNull activeLight) then { deleteVehicle activeLight; };
    };
    
    call stopTfarRelay;
    closeDialog 0;
    diag_log "Disconnected from camera";
};

// Функции поворота камеры
rotateCamLeft = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_Z = (CAMERA_ROT_Z + CAMERA_ROT_STEP) % 360;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

rotateCamRight = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_Z = (CAMERA_ROT_Z - CAMERA_ROT_STEP + 360) % 360;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

rotateCamUp = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_X = CAMERA_ROT_X + CAMERA_ROT_STEP;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

rotateCamDown = {
    if (!CAMERA_ROT_FIXED) then {
        CAMERA_ROT_X = CAMERA_ROT_X - CAMERA_ROT_STEP;
        
        if (multiCamMode) then {
            [selectedMultiCamIndex] call applyCameraRotation;
            private _actualCamIndex = multiCamIndexes select selectedMultiCamIndex;
            camRotationData set [_actualCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        } else {
            call applyCameraRotation;
            camRotationData set [currentCamIndex, [CAMERA_ROT_Z, CAMERA_ROT_X]];
        };
    };
};

// Переключить шаг поворота камеры
toggleStep = {
    switch (CAMERA_ROT_STEP) do {
        case 5:  { CAMERA_ROT_STEP = 15; };
        case 15: { CAMERA_ROT_STEP = 30; };
        case 30: { CAMERA_ROT_STEP = 5; };
    };
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        private _ctrl5304 = _disp displayCtrl 5304;
        if (!isNull _ctrl5304) then {
            _ctrl5304 ctrlSetText format ["ШАГ: %1°", CAMERA_ROT_STEP];
            _ctrl5304 ctrlCommit 0;
        };
    };
    diag_log format ["Rotation step changed to %1°", CAMERA_ROT_STEP];
};

// Переключить фиксацию камеры
toggleFix = {
    CAMERA_ROT_FIXED = !CAMERA_ROT_FIXED;
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        private _ctrl5305 = _disp displayCtrl 5305;
        if (!isNull _ctrl5305) then {
            _ctrl5305 ctrlSetText (if (CAMERA_ROT_FIXED) then {"РАЗБЛОКА"} else {"ФИКСАЦИЯ"});
            _ctrl5305 ctrlCommit 0;
        };
    };
    diag_log format ["Camera rotation fixed: %1", CAMERA_ROT_FIXED];
};

// Переключение между одно- и многокамерным режимом
toggleMultiCamMode = {
    // Удаляем таймер подсветки, если он существует
    if (highlightTimer != -1) then {
        removeMissionEventHandler ["EachFrame", highlightTimer];
        highlightTimer = -1;
    };

    if (multiCamMode) then {
        {
            if (!isNull _x) then {
                _x cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _forEachIndex]];
                camDestroy _x;
            };
        } forEach activeMultiCams;
        
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach multiCameraBase;

        // Удаляем источники света
        {
            if (!isNull _x) then {
                deleteVehicle _x;
            };
        } forEach activeMultiLights;
        
        activeMultiCams = [];
        multiCameraBase = [];
        multiCamIndexes = [];
        nvgEnabledMulti = [];
        activeMultiLights = [];
        
        diag_log format ["Switching to single mode - activeMultiCams: %1, multiCameraBase: %2", activeMultiCams, multiCameraBase];
        
        multiCamMode = false;

        if (currentCamIndex < 0 || currentCamIndex >= count camList) then {
            currentCamIndex = 0 max ((count camList - 1) min currentCamIndex);
            diag_log format ["toggleMultiCamMode: Adjusted currentCamIndex to %1", currentCamIndex];
        };

        private _obj = camList select currentCamIndex;
        if (isNull _obj) exitWith {
            diag_log "toggleMultiCamMode ERROR: Camera object is null";
            hint "Ошибка: Камера недоступна";
        };
        
        if (isNull cameraBase) then {
            cameraBase = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
            cameraBase hideObject true;
        };
        cameraBase setPosASL getPosASL _obj;
        
        if (currentCamIndex >= count camRotationData) then {
            for "_i" from (count camRotationData) to currentCamIndex do {
                camRotationData pushBack [0, 0];
            };
        };

        private _rot = camRotationData select currentCamIndex;
        CAMERA_ROT_Z = _rot select 0;
        CAMERA_ROT_X = _rot select 1;
        
        if (isNull activeCam) then {
            activeCam = "camera" camCreate getPosATL _obj;
            activeCam camSetFov 0.8;
            activeCam camCommit 0;
            activeCam attachTo [cameraBase, [0,0,0]];
            activeCam cameraEffect ["INTERNAL", "BACK", "CameraFeed"];
            "CameraFeed" setPiPEffect [0]; // ПНВ выключено по умолчанию
        } else {
            activeCam camSetPos getPosATL _obj;
            activeCam camCommit 0;
        };

        activeLight = [cameraBase] call createCamLight;
        [cameraBase] call setupTfarRelay;
        
        [currentCamIndex] call applyCameraRotation;
        
        selectedMultiCamIndex = 0;
        
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            private _ctrl5198 = _disp displayCtrl 5198;
            if (!isNull _ctrl5198) then {
                _ctrl5198 ctrlSetText format ["Камера %1", currentCamIndex + 1];
                _ctrl5198 ctrlCommit 0;
            };

            private _ctrl5203 = _disp displayCtrl 5203;
            if (!isNull _ctrl5203) then {
                _ctrl5203 ctrlSetText "ВКЛЮЧИТЬ ПНВ";
                _ctrl5203 ctrlCommit 0;
            };

            private _ctrl5306 = _disp displayCtrl 5306;
            if (!isNull _ctrl5306) then {
                _ctrl5306 ctrlSetText "МУЛЬТИ-РЕЖИМ";
                _ctrl5306 ctrlCommit 0;
            };

            private _ctrl5307 = _disp displayCtrl 5307;
            if (!isNull _ctrl5307) then {
                _ctrl5307 ctrlShow false;
                _ctrl5307 ctrlCommit 0;
            };

            private _ctrl5308 = _disp displayCtrl 5308;
            if (!isNull _ctrl5308) then {
                _ctrl5308 ctrlShow false;
                _ctrl5308 ctrlCommit 0;
            };

            private _ctrl5309 = _disp displayCtrl 5309;
            if (!isNull _ctrl5309) then {
                _ctrl5309 ctrlShow false;
                _ctrl5309 ctrlCommit 0;
            };

            for "_i" from 0 to 7 do {
                private _ctrl = _disp displayCtrl (5400 + _i);
                if (!isNull _ctrl) then { _ctrl ctrlShow false; };
                private _borderCtrl = _disp displayCtrl (5500 + _i);
                if (!isNull _borderCtrl) then { _borderCtrl ctrlShow false; };
                private _textCtrl = _disp displayCtrl (5600 + _i);
                if (!isNull _textCtrl) then { _textCtrl ctrlShow false; };
            };

            private _ctrl5200 = _disp displayCtrl 5200;
            if (!isNull _ctrl5200) then {
                _ctrl5200 ctrlShow true;
                _ctrl5200 ctrlCommit 0;
            };
        };
    } else {
        if (!isNull activeCam) then {
            activeCam cameraEffect ["Terminate", "Back", "CameraFeed"];
            camDestroy activeCam;
        };
        if (!isNull cameraBase) then {
            deleteVehicle cameraBase;
        };
        if (!isNull activeLight) then { deleteVehicle activeLight; };
        
        activeCam = objNull;
        cameraBase = objNull;
        
        call setupMultiCamMode;
        [multiCameraBase select selectedMultiCamIndex] call setupTfarRelay;

        multiCamMode = true;
        selectedMultiCamIndex = 0;
        
        private _disp = findDisplay 5001;
        if (!isNull _disp) then {
            private _ctrl5198 = _disp displayCtrl 5198;
            if (!isNull _ctrl5198) then {
                _ctrl5198 ctrlSetText format ["Мульти-режим - Слот %1 - Камера %2", 
                    selectedMultiCamIndex + 1, (multiCamIndexes select selectedMultiCamIndex) + 1];
                _ctrl5198 ctrlCommit 0;
            };

            private _ctrl5203 = _disp displayCtrl 5203;
            if (!isNull _ctrl5203) then {
                _ctrl5203 ctrlSetText "ВКЛЮЧИТЬ ПНВ";
                _ctrl5203 ctrlCommit 0;
            };

            private _ctrl5306 = _disp displayCtrl 5306;
            if (!isNull _ctrl5306) then {
                _ctrl5306 ctrlSetText "ОДИНОЧНЫЙ РЕЖИМ";
                _ctrl5306 ctrlCommit 0;
            };

            private _ctrl5307 = _disp displayCtrl 5307;
            if (!isNull _ctrl5307) then {
                _ctrl5307 ctrlShow true;
                _ctrl5307 ctrlSetText format ["КАМЕР: %1", multiCamCount];
                _ctrl5307 ctrlCommit 0;
            };

            private _ctrl5308 = _disp displayCtrl 5308;
            if (!isNull _ctrl5308) then {
                _ctrl5308 ctrlShow true;
                _ctrl5308 ctrlCommit 0;
            };

            private _ctrl5309 = _disp displayCtrl 5309;
            if (!isNull _ctrl5309) then {
                _ctrl5309 ctrlShow true;
                _ctrl5309 ctrlCommit 0;
            };
        };
    };
};

// Настройка мульти-камерного режима
setupMultiCamMode = {
    {
        if (!isNull _x) then {
            _x cameraEffect ["Terminate", "Back", format ["MultiCamFeed_%1", _forEachIndex]];
            camDestroy _x;
        };
    } forEach activeMultiCams;
    
    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach multiCameraBase;

    {
        if (!isNull _x) then {
            deleteVehicle _x;
        };
    } forEach activeMultiLights;
    
    activeMultiCams = [];
    multiCameraBase = [];
    multiCamIndexes = [];
    nvgEnabledMulti = [];
    activeMultiLights = [];
    
    for "_i" from 0 to (multiCamCount - 1) do {
        private _camIndex = (currentCamIndex + _i) mod count camList;
        multiCamIndexes pushBack _camIndex;
        nvgEnabledMulti pushBack false; // ПНВ выключено по умолчанию
        activeMultiLights pushBack objNull; // Заполняем массив для источников света
    };
    
    for "_i" from 0 to (multiCamCount - 1) do {
        private _camIndex = multiCamIndexes select _i;
        private _obj = camList select _camIndex;
        
        format ["MultiCamFeed_%1", _i] setPiPEffect [0]; // ПНВ выключено по умолчанию
        
        private _base = "Land_HelipadEmpty_F" createVehicleLocal [0,0,0];
        _base hideObject true;
        _base setPosASL getPosASL _obj;
        multiCameraBase pushBack _base;
        
        private _cam = "camera" camCreate getPosATL _obj;
        _cam camSetFov 0.8;
        _cam camCommit 0;
        _cam attachTo [_base, [0,0,0]];
        _cam cameraEffect ["Internal", "Back", format ["MultiCamFeed_%1", _i]];
        format ["MultiCamFeed_%1", _i] setPiPEffect [0]; // ПНВ выключено по умолчанию
        activeMultiCams pushBack _cam;

        private _light = [_base] call createCamLight;
        activeMultiLights set [_i, _light];
        diag_log format ["Added enhanced light to multi-camera %1", _i];
        
        private _rot = camRotationData select _camIndex;
        if (_i == selectedMultiCamIndex) then {
            CAMERA_ROT_Z = _rot select 0;
            CAMERA_ROT_X = _rot select 1;
        };
        
        _base setVectorDirAndUp [
            [cos (_rot select 0) * cos (_rot select 1), sin (_rot select 0) * cos (_rot select 1), sin (_rot select 1)],
            [0, 0, 1]
        ];
    };
    
    [multiCamCount] call updateMultiCamDisplay;
};

// Обновить отображение мульти-камер
updateMultiCamDisplay = {
    params ["_numCams"];
    
    private _disp = findDisplay 5001;
    if (isNull _disp) exitWith {};
    
    private _ctrl5200 = _disp displayCtrl 5200;
    if (!isNull _ctrl5200) then {
        _ctrl5200 ctrlShow false;
        _ctrl5200 ctrlCommit 0;
    };
    
    private _baseX = safezoneX + (safezoneW - (0.9 * safezoneW)) / 2; // Центрируем по X
    private _baseY = safezoneY + (safezoneH - (0.8 * safezoneH)) / 2; // Центрируем по Y
    private _baseW = 0.9 * safezoneW; // Увеличиваем ширину области камер
    private _baseH = 0.8 * safezoneH; // Увеличиваем высоту области камер
    
    private _cols = switch (_numCams) do {
        case 4: { 2 };
        case 6: { 3 };
        case 8: { 4 };
        default { 2 };
    };
    
    private _rows = ceil (_numCams / _cols);
    private _camW = _baseW / _cols;
    private _camH = _baseH / _rows;
    
    for "_i" from 0 to (_numCams - 1) do {
        private _col = _i mod _cols;
        private _row = floor (_i / _cols);
        
        private _x = _baseX + (_col * _camW);
        private _y = _baseY + (_row * _camH);
        
        private _ctrlId = 5400 + _i;
        private _ctrl = _disp displayCtrl _ctrlId;
        
        if (!isNull _ctrl) then {
            _ctrl ctrlRemoveAllEventHandlers "MouseButtonDown";
        } else {
            _ctrl = _disp ctrlCreate ["RscPicture", _ctrlId];
        };
        
        _ctrl ctrlSetText format ["#(argb,512,512,1)r2t(MultiCamFeed_%1,1.777)", _i];
        _ctrl ctrlSetPosition [_x, _y, _camW, _camH];
        _ctrl ctrlShow true;
        _ctrl ctrlCommit 0;
        
        private _borderCtrlId = 5500 + _i;
        private _borderCtrl = _disp displayCtrl _borderCtrlId;
        
        if (isNull _borderCtrl) then {
            _borderCtrl = _disp ctrlCreate ["RscText", _borderCtrlId];
        };
        
        _borderCtrl ctrlSetPosition [_x, _y, _camW, _camH];
        if (_i == selectedMultiCamIndex) then {
            _borderCtrl ctrlSetTextColor [1, 0, 0, 1];
            _borderCtrl ctrlSetBackgroundColor [1, 0, 0, 0.3];
        } else {
            _borderCtrl ctrlSetTextColor [1, 1, 1, 0];
            _borderCtrl ctrlSetBackgroundColor [0, 0, 0, 0];
        };
        _borderCtrl ctrlShow true;
        _borderCtrl ctrlCommit 0;
        
        private _textCtrlId = 5600 + _i;
        private _textCtrl = _disp displayCtrl _textCtrlId;
        
        if (isNull _textCtrl) then {
            _textCtrl = _disp ctrlCreate ["RscText", _textCtrlId];
        };
        
        private _camIndex = multiCamIndexes select _i;
        _textCtrl ctrlSetText format ["Камера %1", _camIndex + 1];
        _textCtrl ctrlSetPosition [_x + (_camW * 0.05), _y + (_camH * 0.8), _camW * 0.9, _camH * 0.15];
        _textCtrl ctrlSetTextColor [1, 1, 1, 1];
        _textCtrl ctrlShow true;
        _textCtrl ctrlCommit 0;
    };
    
    for "_i" from _numCams to 7 do {
        private _ctrlId = 5400 + _i;
        private _ctrl = _disp displayCtrl _ctrlId;
        if (!isNull _ctrl) then {
            _ctrl ctrlShow false;
            _ctrl ctrlCommit 0;
        };
        
        private _borderCtrlId = 5500 + _i;
        private _borderCtrl = _disp displayCtrl _borderCtrlId;
        if (!isNull _borderCtrl) then {
            _borderCtrl ctrlShow false;
            _borderCtrl ctrlCommit 0;
        };
        
        private _textCtrlId = 5600 + _i;
        private _textCtrl = _disp displayCtrl _textCtrlId;
        if (!isNull _textCtrl) then {
            _textCtrl ctrlShow false;
            _textCtrl ctrlCommit 0;
        };
    };
};

// Циклическое переключение количества камер в мульти-режиме
cycleMultiCamCount = {
    if (!multiCamMode) exitWith {};
    
    switch (multiCamCount) do {
        case 4: { multiCamCount = 6; };
        case 6: { multiCamCount = 8; };
        case 8: { multiCamCount = 4; };
        default { multiCamCount = 4; };
    };
    
    call setupMultiCamMode;
    
    private _disp = findDisplay 5001;
    if (!isNull _disp) then {
        private _ctrl5307 = _disp displayCtrl 5307;
        if (!isNull _ctrl5307) then {
            _ctrl5307 ctrlSetText format ["КАМЕР: %1", multiCamCount];
            _ctrl5307 ctrlCommit 0;
        };
    };
    diag_log format ["MultiCam count changed to %1", multiCamCount];
};

// Добавление действия к терминалу
if (!isNil "terminalObj" && {!isNull terminalObj}) then {
    terminalObj addAction ["Открыть камеры наблюдения", {
        createDialog "CameraMenuDialog";
        private _menuDisp = findDisplay 5000;
        if (isNull _menuDisp) exitWith { diag_log "Terminal action ERROR: Display 5000 not found"; };
        private _listCtrl = _menuDisp displayCtrl 5100;
        if (isNull _listCtrl) exitWith { diag_log "Terminal action ERROR: List control 5100 not found"; };
        lbClear _listCtrl;
        {
            _listCtrl lbAdd format ["Камера %1", _forEachIndex + 1];
        } forEach camList;
        _listCtrl lbSetCurSel 0;
        diag_log "Opened CameraMenuDialog via terminalObj";
    }];
};

// Проверка массива данных поворота камер
if (count camRotationData < count camList) then {
    for "_i" from (count camRotationData) to ((count camList) - 1) do {
        camRotationData pushBack [0, 0];
    };
};