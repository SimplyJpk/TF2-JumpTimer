Database MainDatabase = null;
Database SettingsDatabase = null;

char CreateUserTimeTable[] = "CREATE TABLE IF NOT EXISTS 'Times' ('uniqueID' int(11) KEY NOT NULL AUTO_INCREMENT, 'steamID' varchar(20) NOT NULL, 'map' varchar(64) NOT NULL, 'name' varchar(64) NOT NULL, 'runtime' double NOT NULL, 'class' int(2) NOT NULL, 'timestamp' timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE = InnoDB DEFAULT CHARSET = latin1; ";

int SQL_LastInsertClass[MAXPLAYERS] = -1;

// Connects to Databases
public InitializeDataBase()
{
	static char error[255];
	if (MainDatabase == INVALID_HANDLE)
	{
		MainDatabase = SQL_Connect("details", true, error, sizeof(error));
		if (MainDatabase == INVALID_HANDLE)
		{
			SetFailState(error);
		}
		else
		{
			#if (IsLogging)
			PrintToConsoleAll("[JT] DB | Connected to Database (Details).");
			#endif
			// Creates Tables if they do not exist
			SQL_TQuery(MainDatabase, SQL_EmptyCallback, CreateUserTimeTable);
		}
	}
	if (SettingsDatabase == null)
	{
		SettingsDatabase = SQL_Connect("clientdata", true, error, sizeof(error));
		if (SettingsDatabase == null)
		{
			SetFailState(error);
		}
		else
		{
			// Need to Create settings if not exist here as well
		}
	}
	
	//TODO Need a new CreateTables for ControlPoints
	//SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS controlpoints (map TEXT, bonus INTEGER, num INTEGER, v1 REAL, v2 REAL, v3 REAL, block INTEGER, size REAL DEFAULT 1.0)"); */
	return;
}

// Empty Callback so we can Thread Queries
public SQL_EmptyCallback(Handle owner, Handle hndl, const char[] error, any:data)
{
	if (!StrEqual("", error))
	{
		PrintToServer("SQL Error: %s", error);
	}
	return;
}

void SQL_UpdateInsertUserTime(Database db, DBResultSet results, const char[] error, int client)
{
	if (!StrEqual("", error))
	{
		PrintToServer("SQL Error: %s", error);
	}
	
	if (USER_UniqueID[client][SQL_LastInsertClass[client]] == -1)
		USER_UniqueID[client][SQL_LastInsertClass[client]] = results.InsertId;
	
	//TODO Improve this?
	// Bit backwards, but allows us to finish updating the client from here
	UpdateHighScoreList(client, SQL_LastInsertClass[client]);
	
	#if (IsLogging)
	PrintToConsoleAll("[JT] Map Complete | User %s's time has been saved.", USER_Name[client]);
	#endif
	return;
}

public FetchUserTimes(int client)
{
	Format(GlobalQueryChar, sizeof(GlobalQueryChar), "SELECT uniqueID, runtime, class, timestamp FROM Times WHERE steamID = '%s' AND map = '%s' ORDER BY class ASC", USER_SteamID[client], CurrentMap);
	MainDatabase.Query(SQL_FetchUserTimes, GlobalQueryChar, client, DBPrio_Normal);
}

void SQL_FetchUserTimes(Database db, DBResultSet results, const char[] error, int client)
{
	if (IsClientInGame(client))
	{
		if (results.RowCount <= 0)
			return;
		
		int class = -1;
		while (results.FetchRow())
		{
			class = results.FetchInt(2);
			USER_UniqueID[client][class] = results.FetchInt(0);
			USER_RecordedTime[client][class] = results.FetchFloat(1);
			USER_Timestamp[client][class] = results.FetchInt(3);
		}
	}
} 