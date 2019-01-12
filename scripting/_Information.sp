 //TODO A lot of this information could be cached.. probably not worth the effort though

#define TIMES_CHAT_LIMIT 5

void RegisterInfomationCommands()
{
	RegConsoleCmd("sm_bests", CMD_BestTimes);
	RegConsoleCmd("sm_times", CMD_ClassTimes);
	
	// Class Specific
	RegConsoleCmd("sm_stimes", CMD_SolTimes);
	RegConsoleCmd("sm_dtimes", CMD_DemTimes);
	RegConsoleCmd("sm_ctimes", CMD_ConcTimes);
	RegConsoleCmd("sm_etimes", CMD_EngTimes);
	RegConsoleCmd("sm_ptimes", CMD_PyroTimes);
}

public Action CMD_BestTimes(client, args)
{
	for (int i = 0; i < CLASS_COUNT; i++)
	{
		if (SQL_Time[i][0] > 0)
			CPrintToChat(client, "%s {ORANGE}%s{WHITE} => {LIGHTGREEN}(%s){WHITE}\t by {LIGHTGREEN}%s{WHITE} | {GREY}%s", ChatTag, ClassNamesShort[i], FloatTimeToString(SQL_Time[i][0]), SQL_Name[i][0], TimeStampToString(SQL_TimeStamp[i][0]));
		else
			CPrintToChat(client, "%s {ORANGE}%s{WHITE} => {GREY}(xx:xx.xx){WHITE}\t by {GREY}xxxxxxxxxxxx{WHITE} | {GREY}xx/xx/xx", ChatTag, ClassNamesShort[i], TimeStampToString(SQL_TimeStamp[i][0]));
	}
	return Plugin_Handled;
}

public Action CMD_ClassTimes(client, args)
{
	if (IsClientInGame(client))
	{
		TFClassType playerclass = TF2_GetPlayerClass(client);
		int Index = TFClassAsArrayIndex(playerclass);
		if (Index != -1)
			DisplaySQLTimes(client, Index);
		else
			DisplaySQLTimes(client, view_as<int>(SOL));
	}
	return Plugin_Handled;
}

public Action CMD_SolTimes(client, args) { DisplaySQLTimes(client, view_as<int>(SOL)); }
public Action CMD_DemTimes(client, args) { DisplaySQLTimes(client, view_as<int>(DEM)); }
public Action CMD_ConcTimes(client, args) { DisplaySQLTimes(client, view_as<int>(CONC)); }
public Action CMD_EngTimes(client, args) { DisplaySQLTimes(client, view_as<int>(ENG)); }
public Action CMD_PyroTimes(client, args) { DisplaySQLTimes(client, view_as<int>(PYRO)); }

Action DisplaySQLTimes(int client, int class)
{
	if (SQL_Time[class][0] < 0)
	{
		CPrintToChat(client, "%s{WHITE} This map has no records {ORANGE}%s{WHITE}.", ChatTag, ClassNames[class]);
	}
	else
	{
		for (int i = 0; i < MAX_LOCAL_RECORDS; i++)
		{
			if (SQL_Time[class][i] <= 0)
				break;
			
			if (i < TIMES_CHAT_LIMIT)
				CPrintToChat(client, "%s {ORANGE}%s {WHITE}:{ORANGE} %s {LIGHTGREEN}(%s){WHITE}\t by {LIGHTGREEN}%s", ChatTag, ClassNamesShort[class], PlaceName[i], FloatTimeToString(SQL_Time[class][i]), SQL_Name[class][i]);
			else
				PrintToConsole(client, "%s %s : %s (%s) %tby %s", NoColourChatTag, ClassNamesShort[class], PlaceName[i], FloatTimeToString(SQL_Time[class][i]), SQL_Name[class][i]);
		}
	}
	return Plugin_Handled;
} 