#define MAX_CONTROL_POINTS 12
#define MAX_CPNAME_LENGTH 16

#define CP_ENTITY_MODEL "models/weapons/w_models/w_rocket.mdl"
#define CP_BASE_MODEL "models/props_gameplay/cap_point_base.mdl"

#define CP_CAPTUREAUDIO "ambient/thunder4.wav"
#define CP_FINISH_MAPAUDIO "vo/announcer_success.mp3"
#define CP_FAIL_MAPAUDIO "ambient/cow1.wav"

bool isCPsLoaded = false;
int LoadedCPCount = 0;
int LoadedNormalCPCount = 0;

int CP_UniqueID[MAX_CONTROL_POINTS] =  { -1, ... };
// We don't need to store map
char CP_Name[MAX_CONTROL_POINTS][MAX_CPNAME_LENGTH];
CPTypes CP_Type[MAX_CONTROL_POINTS];
float CP_Position[MAX_CONTROL_POINTS][3];
float CP_MinPoint[MAX_CONTROL_POINTS][3];
float CP_MaxPoint[MAX_CONTROL_POINTS][3];

// Spawned Control Points
int CP_ZoneReferenceIndex[MAX_CONTROL_POINTS] =  { -1 };
int CP_BaseReferenceIndex[MAX_CONTROL_POINTS] =  { -1 };
bool CP_IsUsed[MAX_CONTROL_POINTS] =  { false };

// User Data
bool USER_HasTouchedCP[MAXPLAYERS][MAX_CONTROL_POINTS];
int USER_NormalCPsTouched[MAXPLAYERS] =  { 0 };

public Action Event_LockCPZones(Handle event, const char[] name, bool dontBroadcast)
{
	LockMapControlPoints();
	TryCreateCPZones();
}

/* Disables ControlPoints on the Current Map so that they can not be used for completing the map. */
public LockMapControlPoints()
{
	int iCP = -1;
	while ((iCP = FindEntityByClassname(iCP, "trigger_capture_area")) != -1)
	{
		SetVariantString("2 0");
		AcceptEntityInput(iCP, "SetTeamCanCap");
		SetVariantString("3 0");
		AcceptEntityInput(iCP, "SetTeamCanCap");
		#if (IsLogging)
		PrintToConsoleAll("[JT] Disabled a Natural Control Point");
		#endif
	}
}

public Action TMR_LoadControlPointData(Handle timer)
{
	LoadControlPointData();
}

bool LoadControlPointData()
{
	// Has this map already got required Information Loaded
	if (isCPsLoaded)
		return false;
	
	Format(GlobalQueryChar, sizeof(GlobalQueryChar), "SELECT * FROM MapControlpoints WHERE map = '%s' ORDER BY uniqueid, type ASC", CurrentMap);
	
	MainDatabase.Query(SQLT_LoadCPData, GlobalQueryChar, _, DBPrio_High);
	return true;
}

void SQLT_LoadCPData(Database db, DBResultSet results, const char[] error, any data)
{
	if (results.RowCount > 0)
	{
		while (results.FetchRow())
		{
			if (LoadedCPCount >= MAX_CONTROL_POINTS)
				break;
			else
			{
				CP_UniqueID[LoadedCPCount] = results.FetchInt(0);
				results.FetchString(2, CP_Name[LoadedCPCount], MAX_CPNAME_LENGTH);
				CP_Type[LoadedCPCount] = view_as<CPTypes>(results.FetchInt(3));
				// Position
				CP_Position[LoadedCPCount][0] = results.FetchFloat(4);
				CP_Position[LoadedCPCount][1] = results.FetchFloat(5);
				CP_Position[LoadedCPCount][2] = results.FetchFloat(6);
				// Min
				CP_MinPoint[LoadedCPCount][0] = results.FetchFloat(7);
				CP_MinPoint[LoadedCPCount][1] = results.FetchFloat(9);
				CP_MinPoint[LoadedCPCount][2] = results.FetchFloat(11);
				// Max
				CP_MaxPoint[LoadedCPCount][0] = results.FetchFloat(8);
				CP_MaxPoint[LoadedCPCount][1] = results.FetchFloat(10);
				CP_MaxPoint[LoadedCPCount][2] = results.FetchFloat(12);
				
				if (CP_Type[LoadedCPCount] == CP_NORMAL)
					LoadedNormalCPCount++;
				// Count our CP
				LoadedCPCount++;
			}
		}
		#if (IsLogging)
		PrintToConsoleAll("[JT] DB Load | %i Control Points returned from DB.", LoadedCPCount);
		#endif
		isCPsLoaded = true;
	}
}

public TryCreateCPZones()
{
	CreateTimer(1.0, TMR_LoadControlPoints);
}

public Action TMR_LoadControlPoints(Handle timer, int data)
{
	LoadControlPointZones();
}

void LoadControlPointZones()
{
	for (int i = 0; i < LoadedCPCount; i++)
	{
		if (CP_IsUsed[i])
		{
			// Destroy the Entity if it Exists
			if (CP_ZoneReferenceIndex[i] > 0 && IsValidEntity(EntRefToEntIndex(CP_ZoneReferenceIndex[i])))
				DestroyEntity(EntRefToEntIndex(CP_ZoneReferenceIndex[i]));
			if (CP_BaseReferenceIndex[i] > 0 && IsValidEntity(EntRefToEntIndex(CP_BaseReferenceIndex[i])))
				DestroyEntity(EntRefToEntIndex(CP_BaseReferenceIndex[i]));
			CP_ZoneReferenceIndex[i] = -1;
			CP_BaseReferenceIndex[i] = -1;
			CP_IsUsed[i] = false;
			#if (IsLogging)
			PrintToConsoleAll("[JT] CP Create | %i Zone still Existed, Destroyed.", i);
			#endif
		}
		
		//TODO Consider adding a Error Check for Invalid Trigger here
		int newTrigger = CreateEntityByName("trigger_multiple");
		// General Attributes
		DispatchKeyValue(newTrigger, "StartDisabled", "1");
		DispatchKeyValue(newTrigger, "spawnflags", "1");
		// Set a Model (Required, Unseen)
		SetEntityModel(newTrigger, CP_ENTITY_MODEL);
		// Teleport the Entity to its Position
		TeleportEntity(newTrigger, CP_Position[i], NULL_VECTOR, NULL_VECTOR);
		// Spawn and Resize the Brush to the correct size
		DispatchSpawn(newTrigger);
		SetEntPropVector(newTrigger, Prop_Send, "m_vecMins", CP_MinPoint[i]);
		SetEntPropVector(newTrigger, Prop_Send, "m_vecMaxs", CP_MaxPoint[i]);
		// Set Collisions, probably not Nessisary
		SetEntProp(newTrigger, Prop_Send, "m_nSolidType", 2);
		// Enable
		AcceptEntityInput(newTrigger, "Enable");
		
		// Store our new Trigger
		CP_ZoneReferenceIndex[i] = EntIndexToEntRef(newTrigger);
		CP_IsUsed[i] = true;
		
		// Hook Touch, we work out Type later
		HookSingleEntityOutput(newTrigger, "OnStartTouch", OnCPTouch);
		
		#if (IsLogging)
		PrintToConsoleAll("[JT] CP Create | CP %i (%s) Created.", i, CP_Name[i]);
		#endif
		
		// OutOfBounds is only Type we currently don't want to give a CP
		if (CP_Type[i] != CP_OUTOFBOUNDS)
		{
			SpawnControlPointProp(i);
		}
	}
}

void SpawnControlPointProp(int Index)
{
	int newBase = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(newBase, "physdamagescale", "0.0");
	DispatchKeyValue(newBase, "model", CP_BASE_MODEL);
	// Give it a name, (Probably not Needed)
	DispatchKeyValue(newBase, "targetname", CP_Name[Index]);
	DispatchSpawn(newBase);
	// Teleport
	TeleportEntity(newBase, CP_Position[Index], NULL_VECTOR, NULL_VECTOR);
	// Is this nessisary?
	SetEntityMoveType(newBase, MOVETYPE_NONE);
	
	CP_BaseReferenceIndex[Index] = EntIndexToEntRef(newBase);
	
	#if (IsLogging)
	PrintToConsoleAll("[JT] CP Create | Prop Model for %i (%s) spawned.", Index, CP_Name[Index]);
	#endif
}


public OnCPTouch(const char[] output, caller, client, float delay)
{
	OnCPTouch_Handler(client, EntIndexToEntRef(caller));
}

void OnCPTouch_Handler(int client, int entRefIndex)
{
	if (entRefIndex == INVALID_ENT_REFERENCE)
		return;
	if (IsFakeClient(client))
		return;
	
	for (int cpIndex = 0; cpIndex < LoadedCPCount; cpIndex++)
	{
		// We need updates only on the right Index
		if (entRefIndex != CP_ZoneReferenceIndex[cpIndex])
			continue;
		if (USER_HasTouchedCP[client][cpIndex])
			break;
		
		USER_HasTouchedCP[client][cpIndex] = true;
		if (CP_Type[cpIndex] == CP_NORMAL)
		{
			EmitSoundToAll(CP_CAPTUREAUDIO, _, _, SNDLEVEL_FRIDGE, _, SNDVOL_NORMAL, _, _, _, _, _, _);
			USER_NormalCPsTouched[client]++;
			if (USER_NormalCPsTouched[client] >= LoadedNormalCPCount)
			{
				// Finished Map
				CompleteMap(client);
				
				#if (IsLogging)
				PrintToConsoleAll("[JT] CP Touch | User %i touched the Final CP %i (%s)", client, cpIndex, CP_Name[cpIndex]);
				#endif
			}
			else
			{
				if (USER_StartTime[client] > 0)
				{
					float TimePassed = GetEngineTime() - USER_StartTime[client];
					
					CPrintToChatAll("%s {ORANGE}%s{WHITE} reached zone {ORANGE}%i{WHITE} of {ORANGE}%i{WHITE} {LIGHTBLUE}(%s)", ChatTag, USER_Name[client], USER_NormalCPsTouched[client], LoadedNormalCPCount, FloatTimeToString(TimePassed));
				}
				else
				{
					CPrintToChatAll("%s {ORANGE}%s{WHITE} reached zone {ORANGE}%i{WHITE} of {ORANGE}%i", ChatTag, USER_Name[client], USER_NormalCPsTouched[client], LoadedNormalCPCount);
				}
			}
			
			#if (IsLogging)
			PrintToConsoleAll("[JT] CP Touch | User %i touched the Normal CP %i (%s)", client, cpIndex, CP_Name[cpIndex]);
			#endif
		}
		else if (CP_Type[cpIndex] == CP_BONUS)
		{
			//TODO make Bonus system
			// A Bonus CP!
			
			#if (IsLogging)
			PrintToConsoleAll("[JT] CP Touch | User %i touched the Bonus CP %i (%s)", client, cpIndex, CP_Name[cpIndex]);
			#endif
		}
		else if (CP_Type[cpIndex] == CP_OUTOFBOUNDS)
		{
			//TODO Oh no, Out of bounds
			
			#if (IsLogging)
			PrintToConsoleAll("[JT] CP Touch | User %i touched out of bounds CP %i (%s)", client, cpIndex, CP_Name[cpIndex]);
			#endif
		}
		// Escape the Loop
		break;
	}
}

void ResetControlPoints(int client)
{
	for (int i = 0; i < MAX_CONTROL_POINTS; i++)
	{
		USER_HasTouchedCP[client][i] = false;
	}
	USER_NormalCPsTouched[client] = 0;
}

bool DestroyEntity(int entref)
{
	int entIndex = EntRefToEntIndex(entref);
	if (entIndex != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entIndex, "kill");
		return true;
	}
	return false;
} 