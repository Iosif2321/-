params["_type","_params"];
private _display=ctrlParent (_params#0);
private _text=ctrlText (_display displayCtrl 1);
private _board=missionNamespace getVariable["tb_currentBoard",objNull];
[_board,_text] remoteExecCall["tb_fnc_setText",2];
missionNamespace setVariable["tb_currentBoard",nil];
closeDialog 1;
