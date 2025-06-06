params["_board"];
if(isNull _board)exitWith{};
missionNamespace setVariable["tb_currentBoard",_board];
createDialog "TB_InputDialog";
