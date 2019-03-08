public CheckFailure(int client, EFailureType reason, const char[] Message, int MsgLength)
{
	
	if (IsClientInGame(client))
	{
		if (USER_StartTime[client] > 0)
		{
			USER_StartTime[client] = -1.0;
			
			if (MsgLength > 0)
				CPrintToChat(client, "%s %s", ChatTag, Message);
			else if (reason == OUT_OF_BOUNDS)
				CPrintToChat(client, "%s {RED}Timer Disabled!{WHITE} (Out of Bounds!)", ChatTag, Message);
			else
				CPrintToChat(client, "%s Marked as Failed! {RED}Timer Disabled!", ChatTag);
			
			#if (IsLogging)
			PrintToConsoleAll("[JT] Forward : Fail | Client #%i Failed!", GetClientUserId(client));
			#endif
		}
	}
} 