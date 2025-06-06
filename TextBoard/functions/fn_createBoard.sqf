params["_target"];
if(isNull _target)exitWith{objNull};
if(!isServer)exitWith{[_target] remoteExecCall["tb_fnc_createBoard",2]};
private _dir=getDir _target;
private _board="Land_InfoStand_V1_F" createVehicle [0,0,0];
_board setDir _dir;
_board setPosATL (_target modelToWorld [0,1,1]);
_board setVariable["tb_text","",true];
[_board] remoteExec["tb_fnc_addDrawHandler",0,true];
_board
