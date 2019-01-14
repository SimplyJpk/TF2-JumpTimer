#pragma semicolon 1
#define PLUGIN_VERSION "0.8.0"

char ChatTag[] = "{LIGHTGREEN}[∞]{WHITE}";
char NoColourChatTag[] = "[∞]";

const bool IsLogging = true;
bool LateLoading = true;

#define MAX_PLAYER_NAME_LENGTH 32

// My Include
#include "JumpTimer" 

#include <sourcemod>
#include <morecolors>
#include <sdktools>
#include <tf2_stocks>
// Used for Resetting
#include <sdkhooks>

// Variables that are needed by more than one Script
char GlobalQueryChar[400];
char CurrentMap[30];
char ClassNames[TimerClass][] =  { "Soldier", "Demoman", "Conc", "Engineer", "Pyro" };
char ClassNamesShort[TimerClass][] =  { "S", "D", "C", "E", "P" };

// Record Variables
//TODO Do we want to move these into Database.sp?
#define MAX_LOCAL_RECORDS 10
#define MAX_STEAMID_LENGTH 20
#define TIMESTRING_LENGTH 16
#define DATESTRING_LENGTH 12
#define PlaceNameLength 5

char PlaceName[MAX_LOCAL_RECORDS][PlaceNameLength] =  { "1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th" };

int SQL_UniqueID[TimerClass][MAX_LOCAL_RECORDS];
char SQL_SteamID[TimerClass][MAX_LOCAL_RECORDS][MAX_STEAMID_LENGTH];
char SQL_Name[TimerClass][MAX_LOCAL_RECORDS][MAX_PLAYER_NAME_LENGTH * 2 + 1];
float SQL_Time[TimerClass][MAX_LOCAL_RECORDS];
int SQL_TimeStamp[TimerClass][MAX_LOCAL_RECORDS];

// Player Variables
float USER_StartTime[MAXPLAYERS] =  { -1.0 };
float USER_FinishTime[MAXPLAYERS] =  { -1.0 };

char USER_SteamID[MAXPLAYERS][MAX_STEAMID_LENGTH];
char USER_Name[MAXPLAYERS][MAX_PLAYER_NAME_LENGTH * 2 + 1];

// TODO Consider making this TimerClass:MaxPlayers instead of the other way around?
float USER_RecordedTime[MAXPLAYERS][TimerClass];
int USER_UniqueID[MAXPLAYERS][TimerClass];
int USER_Timestamp[MAXPLAYERS][TimerClass];

int USER_Weapons[MAXPLAYERS][WeaponCheckTypes];

// Additional Scripts
#include "_Database.sp" // Init, Save, Load
#include "_ControlPoints.sp" // Might remove this into another script
#include "_Timers.sp" // Mostly for showing the timer and timer information to client
#include "_Information.sp" // Command responses for Information
#include "_Toolbelt.sp" // Collection of methods that dont fit in elsewhere
#include "_FailCheck.sp" // 

public Plugin myinfo = 
{
	name = "TF2 Jump Timer", 
	author = "SimplyJpk", 
	description = "Provides a collection of features to enable jump servers to time and track users jumping through the map.", 
	version = PLUGIN_VERSION, 
	url = "http://www.simplyjpk.com/"
}

public void OnPluginStart()
{
	HUD_TimerDisplay = CreateHudSynchronizer();
	// Some Methods need this
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	InitializeDataBase();
	// Events
	HookEvent("teamplay_round_active", Event_LockCPZones, EventHookMode_Post);
	HookEvent("player_team", Event_PlayerJoinedTeam, EventHookMode_Post);
	
	HookEvent("player_changeclass", Event_PlayerChangeClass, EventHookMode_Pre);
	HookEvent("player_death", Event_OnPlayerDeath, EventHookMode_Post);
	// When INV Changes
	HookEvent("post_inventory_application", Event_InvApplication, EventHookMode_Post);
	
	HookEvent("player_teleported", Event_ClientTeleported, EventHookMode_Pre);
	
	LockMapControlPoints();
	
	RegConsoleCmd("sm_r", Command_ResetTime);
	RegConsoleCmd("sm_restart", Command_ResetTime);
	RegConsoleCmd("sm_timeme", Command_ResetTime);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		ClearClientTimeData(i);
		
		if (IsClientInGame(i))
			OnClientPostAdminCheck(i);
	}
	LateLoading = false;
	
	RegisterInfomationCommands(); // Information.sp 
	
	AddCommandListener(SimpleCheatEnd, "sm_t");
	AddCommandListener(SimpleCheatEnd, "sm_tele");
	AddCommandListener(SimpleCheatEnd, "sm_teleport");
}

public Action Command_ResetTime(int client, int args)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		SDKHooks_TakeDamage(client, client, client, 9999.0);
		PrintToConsole(client, "%s Timer Reset.", NoColourChatTag);
		return Plugin_Handled;
	}
	CPrintToChat(client, "%s Must be alive to reset!", ChatTag);
	return Plugin_Handled;
}


// Used to Detect cheating until I implement the forward into the Teleport plugin
public Action SimpleCheatEnd(int client, const char[] command, int args)
{  // If something that may be cheatable is used
	if (IsClientInGame(client))
	{
		if (USER_StartTime[client] > 0)
		{
			CPrintToChat(client, "%s Used Teleport. {RED}Timer Disabled!", ChatTag);
			USER_StartTime[client] = -1.0;
			
			#if (IsLogging)
			PrintToConsoleAll("[JT] Cheat | Client #%i used Teleport!", GetClientUserId(client));
			#endif
		}
	}
}

public OnConfigsExecuted()
{
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	InitializeDataBase(); // Database.sp
	
	LoadControlPointData(); // ControlPoints.sp
	
	// Checks if CPs are Loaded, if not, Creates them in 2 seconds
	TryCreateCPZones();
	
	// Any way to use a loop? and/or my .inc Types?
	LoadStoredTimes(view_as<int>(SOL));
	LoadStoredTimes(view_as<int>(DEM));
	LoadStoredTimes(view_as<int>(CONC));
	LoadStoredTimes(view_as<int>(ENG));
	LoadStoredTimes(view_as<int>(PYRO));
}

public OnMapStart()
{
	ResetMainTimer();
	
	// Models
	PrecacheModel(CP_BASE_MODEL);
	// Audio Files
	PrecacheSound(CP_CAPTUREAUDIO);
	PrecacheSound(CP_FINISH_MAPAUDIO);
	PrecacheSound(CP_FAIL_MAPAUDIO);
}

public OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		USER_NormalCPsTouched[i] = 0;
		USER_StartTime[i] = -1.0;
		// We only go to LoadedCP as we shouldn't have values higher than it
		for (int j = 0; j < LoadedCPCount; j++)
		{
			USER_HasTouchedCP[i][j] = false;
		}
		
		ClearClientTimeData(i);
	}
	isCPsLoaded = false;
	LoadedCPCount = 0;
	LoadedNormalCPCount = 0;
}

public Action Event_OnPlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients)
	{
		if (!IsClassTimerEnabled(TF2_GetPlayerClass(client)))
		{
			USER_StartTime[client] = -1.0;
			return Plugin_Continue;
		}
		ResetTime(client);
		if (TF2_GetPlayerClass(client) == TFClass_Engineer)
			DestroyBuildings(client);
	}
	return Plugin_Continue;
}

public Action Event_InvApplication(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients)
	{
		// Incase another plugin fires a fake event
		int wepIndex = 0;
		
		// Player is Starting new run
		if (GetEngineTime() - USER_StartTime[client] < 10.0)
		{
			StoreUserWeapons(client);
			return Plugin_Continue;
		}
		
		// We don't want to check if we're note already doing a run
		if (IsPlayerAlive(client) && USER_StartTime[client] > 0.0)
		{
			for (int Slot = 0; Slot < WeaponCheckCount; Slot++)
			{
				wepIndex = GetEntProp(GetPlayerWeaponSlot(client, Slot), Prop_Send, "m_iItemDefinitionIndex");
				
				if (USER_Weapons[client][Slot] != wepIndex)
				{
					USER_StartTime[client] = -1.0;
					CPrintToChat(client, "%s Your %s Weapon changed. {RED}Timer Disabled!", ChatTag, WeaponCheckNames[Slot]);
					
					#if (IsLogging)
					PrintToConsoleAll("[JT] Wep Change | Client #%i Changed Weapons during a Run!", GetClientUserId(client));
					#endif
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action Event_ClientTeleported(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (client > 0 && client <= MaxClients)
	{
		// If it was their own teleporter
		int builder = GetClientOfUserId(GetEventInt(event, "builderid"));
		if (client == builder)
			return Plugin_Continue;
		else
		{
			if (USER_StartTime[client] > 0)
			{
				CPrintToChat(client, "%s You were Teleported. {RED}Timer Disabled!", ChatTag);
				USER_StartTime[client] = -1.0;
				
				#if (IsLogging)
				PrintToConsoleAll("[JT] Teleported | Client #%i used client %i teleporter!", GetClientUserId(client), GetClientUserId(builder));
				#endif
			}
		}
	}
	return Plugin_Continue;
}

bool IsBannedWeapon(int Slot, int WeaponIndex)
{
	for (int index = 0; index < sizeof(Blocked_Weapons[]); index++)
	{
		if (Blocked_Weapons[Slot][index] == 0)return false;
		if (WeaponIndex == Blocked_Weapons[Slot][index])
			return true;
	}
	return false;
}

public Action Event_PlayerJoinedTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetTime(client);
	return Plugin_Continue;
}

public Action Event_PlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	TFClassType class = view_as<TFClassType>(GetEventInt(event, "class"));
	TFClassType oldclass = TF2_GetPlayerClass(client);
	
	if (!IsClassTimerEnabled(class))
	{
		USER_StartTime[client] = -1.0;
		return Plugin_Continue;
	}
	
	if (class == oldclass)
		return Plugin_Continue;
	else
		CreateTimer(0.01, Timer_ResetTime, client);
	
	return Plugin_Continue;
}

public Action Timer_ResetTime(Handle timer, int client)
{
	if (IsClientInGame(client))
		ResetTime(client);
}


public OnClientPostAdminCheck(client)
{
	if (!IsFakeClient(client))
	{
		USER_FinishTime[client] = -1.0;
		// Better Safe then sorry
		ResetTime(client);
		
		GetClientName(client, USER_Name[client], MAX_PLAYER_NAME_LENGTH);
		SQL_EscapeString(MainDatabase, USER_Name[client], USER_Name[client], sizeof(USER_Name[]));
		
		GetClientAuthId(client, AuthId_SteamID64, USER_SteamID[client], sizeof(USER_SteamID[]), true);
		
		FetchUserTimes(client);
	}
}

void ResetTime(int client)
{
	if (IsClientInGame(client))
	{
		ResetControlPoints(client); // ControlPoints.sp
		
		USER_FinishTime[client] = -1.0;
		if (!LateLoading)
			USER_StartTime[client] = GetEngineTime();
		
		// 1th a second, is this too long? is the Minimum SM can do, may need OnGameFrame
		CreateTimer(0.01, Timer_StoreWep, client);
		
		#if (IsLogging)
		PrintToConsoleAll("[JT] Reset Time | Client #%i time Reset", GetClientUserId(client));
		#endif
	}
}

public Action Timer_StoreWep(Handle timer, int client)
{
	if (IsClientInGame(client))
		StoreUserWeapons(client);
}

void StoreUserWeapons(int client)
{
	int Weapon = 0;
	for (int slot = 0; slot < WeaponCheckCount; slot++)
	{
		Weapon = GetPlayerWeaponSlot(client, slot);
		if (!IsValidEntity(Weapon))
		{
			USER_Weapons[client][slot] = -1;
		}
		else
		{
			USER_Weapons[client][slot] = GetEntProp(Weapon, Prop_Send, "m_iItemDefinitionIndex");
			if (IsBannedWeapon(slot, USER_Weapons[client][slot]))
			{
				if (USER_StartTime[client] > 0)
				{
					USER_StartTime[client] = -1.0;
					CPrintToChat(client, "%s Your %s Weapon is restricted. {RED}Timer Disabled!", ChatTag, WeaponCheckNames[slot]);
					
					#if (IsLogging)
					PrintToConsoleAll("[JT] Store Weapons | Client #%i using Restricted Weapons!", GetClientUserId(client));
					#endif
				}
			}
		}
	}
}

public bool IsClassTimerEnabled(TFClassType class)
{
	if (class == TFClass_Soldier || class == TFClass_DemoMan || class == TFClass_Pyro || class == TFClass_Engineer || class == TFClass_Sniper)
		return true;
	return false;
}

void CompleteMap(int client)
{
	EmitSoundToClient(client, CP_FINISH_MAPAUDIO, _, _, SNDLEVEL_SCREAMING, _, SNDVOL_NORMAL, _, _, _, _, _, _);
	
	if (USER_StartTime[client] < 1.0)
		return;
	
	int class = view_as<int>(TF2_GetPlayerClass(client));
	
	if (!IsClassTimerEnabled(view_as<TFClassType>(class)))
	{
		//TODO Pretty this up
		CPrintToChat(client, "%s Completed class not supported by Timer!", ChatTag);
		return;
	}
	
	class = TFClassAsArrayIndex(view_as<TFClassType>(class));
	
	// Update Users Name
	GetClientName(client, USER_Name[client], sizeof(USER_Name[]));
	// Cache EngineTime and Work out Completed Time
	float EngTime = GetEngineTime();
	USER_FinishTime[client] = EngTime;
	
	float CompleteTime = EngTime - USER_StartTime[client];
	
	// If the user already has a time for the class
	if (USER_UniqueID[client][class] != -1)
	{
		float CompleteDifference = CompleteTime - USER_RecordedTime[client][class];
		bool neg = (CompleteDifference < 0);
		if (neg)CompleteDifference = -CompleteDifference;
		
		CPrintToChatAll("%s {ORANGE}%s{WHITE} finished as {ORANGE}%s{WHITE}. {LIGHTBLUE}(%s) {%s}(%s)", ChatTag, USER_Name[client], ClassNames[class], FloatTimeToString(CompleteTime), (neg ? "LIGHTGREEN" : "LIGHTPINK"), FloatTimeToString(CompleteDifference));
		
		// Only Update if we have a Faster Time
		if (CompleteTime > USER_RecordedTime[client][class])
			return;
		// Update values if faster, we don't want to do additional calls for just this
		USER_RecordedTime[client][class] = CompleteTime;
		USER_Timestamp[client][class] = GetTime();
		
		#if (IsLogging)
		PrintToConsoleAll("[JT] Map Complete | User %s got a new personal fastest time.", USER_Name[client]);
		#endif
		
		Format(GlobalQueryChar, sizeof(GlobalQueryChar), "UPDATE Times SET name = '%s', runtime = %f, timestamp = %i WHERE steamID = '%s' AND map = '%s' AND class = %i", USER_Name[client], CompleteTime, GetTime(), USER_SteamID[client], CurrentMap, class);
	}
	else
	{
		USER_RecordedTime[client][class] = CompleteTime;
		USER_Timestamp[client][class] = GetTime();
		
		CPrintToChatAll("%s {ORANGE}%s{WHITE} finished as {ORANGE}%s{WHITE}. {LIGHTBLUE}(%s)", ChatTag, USER_Name[client], ClassNames[class], FloatTimeToString(CompleteTime));
		
		#if (IsLogging)
		PrintToConsoleAll("[JT] Map Complete | User %s beat the map for the first time.", USER_Name[client]);
		#endif
		
		Format(GlobalQueryChar, sizeof(GlobalQueryChar), "INSERT INTO Times (steamID, map, name, runtime, class, timestamp) VALUES ('%s', '%s', '%s', %f, %i, %i)", USER_SteamID[client], CurrentMap, USER_Name[client], CompleteTime, class, GetTime());
	}
	
	// Allows me to not worry about creating a datapacket for Client + Class
	SQL_LastInsertClass[client] = class;
	
	// Insert / Update our stuff
	MainDatabase.Query(SQL_UpdateInsertUserTime, GlobalQueryChar, client, DBPrio_Normal);
}

void LoadStoredTimes(int class)
{
	Format(GlobalQueryChar, sizeof(GlobalQueryChar), "SELECT uniqueID, steamID, name, runtime, timestamp FROM Times WHERE map = '%s' AND class = '%i' ORDER BY runtime ASC LIMIT %i", CurrentMap, class, MAX_LOCAL_RECORDS);
	
	MainDatabase.Query(SQLT_LoadRecordData, GlobalQueryChar, class, DBPrio_Normal);
}

void SQLT_LoadRecordData(Database db, DBResultSet results, const char[] error, int class)
{
	int rank = 0;
	if (results.RowCount > 0)
	{
		// Fetch all records we have
		while (results.FetchRow())
		{
			SQL_UniqueID[class][rank] = results.FetchInt(0);
			results.FetchString(1, SQL_SteamID[class][rank], MAX_STEAMID_LENGTH);
			results.FetchString(2, SQL_Name[class][rank], MAX_PLAYER_NAME_LENGTH);
			SQL_Time[class][rank] = results.FetchFloat(3);
			SQL_TimeStamp[class][rank] = results.FetchInt(4);
			rank++;
		}
		#if (IsLogging)
		PrintToConsoleAll("[JT] Loading Times | %i Records loaded for class %i", rank, view_as<int>(class));
		#endif
	}
	// Clear everything else since we won't always have 10 records
	for (int i = rank; i < MAX_LOCAL_RECORDS; i++)
	{
		SQL_UniqueID[class][i] = -1;
		SQL_SteamID[class][i][0] = '\0';
		SQL_Name[class][i][0] = '\0';
		SQL_Time[class][i] = -1.0;
		SQL_TimeStamp[class][i] = -1;
	}
}

// Might need eventually
int TFClassAsArrayIndex(TFClassType class)
{
	if (class == TFClass_Soldier)return view_as<int>(SOL);
	if (class == TFClass_DemoMan)return view_as<int>(DEM);
	if (class == TFClass_Sniper)return view_as<int>(CONC);
	if (class == TFClass_Engineer)return view_as<int>(ENG);
	if (class == TFClass_Pyro)return view_as<int>(PYRO);
	return -1;
}

// void CheckFailure(client, EFailureType:reason, bool check = true)
// {
// 	
// } 

void ClearClientTimeData(int client)
{
	for (int i = 1; i < CLASS_COUNT; i++)
	{
		USER_RecordedTime[client][i] = -1.0;
		USER_Timestamp[client][i] = -1;
		USER_UniqueID[client][i] = -1;
	}
}

void UpdateHighScoreList(int client, int class)
{
	// Check if we even need to Sort
	if (USER_RecordedTime[client][class] > SQL_Time[class][MAX_LOCAL_RECORDS - 1] && SQL_Time[class][MAX_LOCAL_RECORDS - 1] > 0)
		return;
	
	#if (IsLogging)
	PrintToConsoleAll("[JT] Updating HighScores | %i is faster than a Time!", client);
	#endif
	
	int NewPlace = GetPositionInTimes(USER_RecordedTime[client][class], class);
	
	// This should never happen, but eh?
	if (NewPlace == -1)
		return;
	
	#if (IsLogging)
	PrintToConsoleAll("[JT] Updating HighScores | %i was fast enough to get into records!", client);
	#endif
	
	int UserOldPosition = UserPositionInTimes(client, class);
	
	// Same Place, faster time
	if (UserOldPosition != -1 && (NewPlace == UserOldPosition - 1 || NewPlace == UserOldPosition + 1))
	{
		#if (IsLogging)
		PrintToConsoleAll("[JT] Updating HighScores | %i Improved on their own record, no new place!", client);
		#endif
		SQL_Name[class][NewPlace] = USER_Name[client];
		SQL_Time[class][NewPlace] = USER_RecordedTime[client][class];
		SQL_TimeStamp[class][NewPlace] = USER_Timestamp[client][class];
	}
	else
	{
		#if (IsLogging)
		PrintToConsoleAll("[JT] Updating HighScores | %i Got a new Place!", client);
		#endif
		// Replaced someone elses Time
		if (NewPlace >= 0 && SQL_Time[class][NewPlace] > 0)
		{
			CPrintToChatAll("%s {ORANGE}%s{WHITE} beat %s {ORANGE}%s place %s{WHITE} time. {LIGHTGREEN}(%s){WHITE} vs {LIGHTPINK}(%s)", ChatTag, USER_Name[client], SQL_Name[class][NewPlace], PlaceName[NewPlace], ClassNames[class], FloatTimeToString(USER_RecordedTime[client][class]), FloatTimeToString(SQL_Time[class][NewPlace]));
		}
		else
		{
			CPrintToChatAll("%s {ORANGE}%s{WHITE} recieved the {ORANGE}%s place %s{WHITE} time. {LIGHTGREEN}(%s)", ChatTag, USER_Name[client], PlaceName[NewPlace], ClassNames[class], FloatTimeToString(USER_RecordedTime[client][class]));
		}
		
		// TODO This may need some more work, but should work? Math is hard
		if (UserOldPosition >= 0)
			ShiftUserTimes(UserOldPosition, NewPlace, class);
		else
			ShiftUserTimes(MAX_LOCAL_RECORDS - 1, NewPlace, class);
		// Set our Newest record
		SQL_UniqueID[class][NewPlace] = USER_UniqueID[client][class];
		SQL_SteamID[class][NewPlace] = USER_SteamID[client];
		SQL_Name[class][NewPlace] = USER_Name[client];
		SQL_Time[class][NewPlace] = USER_RecordedTime[client][class];
		SQL_TimeStamp[class][NewPlace] = USER_Timestamp[client][class];
	}
}

// TODO Not Ideal, should I store Minutes/Seconds/TimeString? We re-use it a bit
char TimeString[TIMESTRING_LENGTH];
char[] FloatTimeToString(float time)
{
	int Minutes = RoundToFloor(time / 60);
	float Seconds = time - (Minutes * 60);
	Format(TimeString, TIMESTRING_LENGTH, "%s%i:%s%0.2f", (Minutes < 10 ? "0" : ""), Minutes, (Seconds < 10 ? "0" : ""), Seconds);
	return TimeString;
}

char DateString[DATESTRING_LENGTH];
char[] TimeStampToString(int time)
{
	FormatTime(DateString, DATESTRING_LENGTH, "%d/%m/%y", time);
	return DateString;
}

void ShiftUserTimes(int start, int end, int class)
{
	for (int index = start; index > end; index--)
	{
		if (index == MAX_LOCAL_RECORDS - 1 || index == 0)
			continue;
		SQL_UniqueID[class][index] = SQL_UniqueID[class][index - 1];
		SQL_SteamID[class][index] = SQL_SteamID[class][index - 1];
		SQL_Name[class][index] = SQL_Name[class][index - 1];
		SQL_Time[class][index] = SQL_Time[class][index - 1];
		SQL_TimeStamp[class][index] = SQL_TimeStamp[class][index - 1];
	}
}

int UserPositionInTimes(int client, int class)
{
	// We work backwards since most people will have slower times
	for (int i = MAX_LOCAL_RECORDS - 1; i > 0; i--)
	{
		if (USER_UniqueID[client][class] == -1)
			continue;
		if (StrEqual(SQL_SteamID[class][i], USER_SteamID[client], false))
			return i;
	}
	return -1;
}

// Put this in a seperate script, toolbelt?
int GetPositionInTimes(float time, int class)
{
	for (int i = 1; i < MAX_LOCAL_RECORDS; i++)
	{
		if (SQL_Time[class][i] <= 0 || SQL_Time[class][i] > time)
			return i;
	}
	return -1;
} 