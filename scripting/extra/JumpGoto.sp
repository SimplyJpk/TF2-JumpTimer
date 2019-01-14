#pragma semicolon 1
#include "JumpTimer"

#include <sourcemod>
#include <sdktools_functions>
#include <sdktools>
#include <morecolors>

// Very Crude Goto plugin, will improve it later, but for the time being is functional

#define PLUGIN_VERSION "0.0.1"

#define TIMEBETWEENGOTO 10.0
#define FAILMSG_STRING "{LIGHTGREEN}[GO]{WHITE} Player Teleported, {RED}Timer Disabled!"

char ChatTag[] = "{LIGHTGREEN}[GO]{WHITE}";

#define EXTRA_HEIGHT 73

bool GoHook[MAXPLAYERS];

float LastUsed[MAXPLAYERS];

Handle g_FailureForward;

public Plugin myinfo = 
{
	name = "Jump Goto", 
	author = "SimplyJpk", 
	description = "Allows players to Goto each other, but also disable goto if people abuse it.", 
	version = PLUGIN_VERSION, 
	url = "http://www.simplyjpk.com"
}

public OnPluginStart()
{
	RegConsoleCmd("sm_goto", CMD_Goto);
	RegConsoleCmd("sm_go", CMD_GotoEnable);
	RegConsoleCmd("sm_accept", CMD_GotoEnable);
	RegConsoleCmd("sm_reject", CMD_GotoEnable);
	
	g_FailureForward = CreateGlobalForward("CheckFailure", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_Cell);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
			OnClientPostAdminCheck(i);
	}
}
// (int client, EFailureType reason, const char[] Message, int MsgLength);

public OnClientPostAdminCheck(client)
{
	if (!IsFakeClient(client))
	{
		GoHook[client] = true;
		LastUsed[client] = 0.0;
	}
}

public Action CMD_Goto(client, args)
{
	if (GetEngineTime() - LastUsed[client] < TIMEBETWEENGOTO)
	{
		CPrintToChat(client, "%s Please wait at least 10 seconds.", ChatTag);
		return Plugin_Handled;
	}
	if (args < 1)
	{
		CPrintToChat(client, "%s Usage:{LIGHTGREEN}sm_goto <name>", ChatTag);
		return Plugin_Handled;
	}
	//Declare:
	int Player;
	char PlayerName[32];
	float TeleportOrigin[3];
	float PlayerOrigin[3];
	char Name[32];
	Player = -1;
	GetCmdArg(1, PlayerName, sizeof(PlayerName));
	for (new X = 1; X <= MaxClients && Player == -1; X++)
	{
		if (!IsClientInGame(X))continue;
		
		GetClientName(X, Name, sizeof(Name));
		if (StrContains(Name, PlayerName, false) != -1)
		{
			Player = X;
			if (X == client)
				return Plugin_Handled;
			if (HasFlag(client))
				break;
			if (!GoHook[X])
			{
				Player = -1;
			}
		}
	}
	if (Player == -1)
	{
		CPrintToChat(client, "%s target \"{LIGHTPINK}%s{WHITE}\" was not found, or has Goto Access Denied!", ChatTag, PlayerName);
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(Player))
	{
		CPrintToChat(client, "%s Target must be alive!", ChatTag);
		return Plugin_Handled;
	}
	
	// Push our lame forward
	Call_StartForward(g_FailureForward);
	Call_PushCell(client);
	Call_PushCell(GENERIC_FAIL);
	Call_PushString(FAILMSG_STRING);
	Call_PushCell(strlen(FAILMSG_STRING));
	Call_Finish();
	
	GetClientName(Player, Name, sizeof(Name));
	GetClientAbsOrigin(Player, PlayerOrigin);
	
	LastUsed[client] = GetEngineTime();
	
	//Math
	TeleportOrigin[0] = PlayerOrigin[0];
	TeleportOrigin[1] = PlayerOrigin[1];
	TeleportOrigin[2] = (PlayerOrigin[2] + EXTRA_HEIGHT);
	
	//Teleport
	TeleportEntity(client, TeleportOrigin, NULL_VECTOR, NULL_VECTOR);
	return Plugin_Handled;
}

public Action CMD_GotoEnable(client, args)
{
	if (IsClientInGame(client))
	{
		GoHook[client] = !GoHook[client];
		CPrintToChat(client, "%s Goto now %s!", ChatTag, (GoHook[client] ? "Enabled" : "Disabled"));
	}
	return Plugin_Handled;
}

stock HasFlag(client)
{
	AdminId admin = GetUserAdmin(client);
	if (admin != INVALID_ADMIN_ID)
	{
		if (GetAdminFlag(admin, Admin_Generic, Access_Effective) == true)
			return true;
		if (GetAdminFlag(admin, Admin_Custom4, Access_Effective) == true)
			return true;
	}
	return false;
} 