params["_board"];
if(isNull _board)exitWith{};
private _id=addMissionEventHandler["Draw3D",{params["_id"];private _b=missionNamespace getVariable["tb_board_"+str _id,objNull];if(isNull _b)exitWith{removeMissionEventHandler["Draw3D",_id]};drawIcon3D["",[1,1,1,1],_b modelToWorld[0,0,1],0,0,0,_b getVariable["tb_text",""],2,0.05,"RobotoCondensed"];}];
_board setVariable["tb_eh",_id];
missionNamespace setVariable["tb_board_"+str _id,_board];
