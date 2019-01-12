#define UPDATE_INTERVAL 0.1
#define TMR_BOX_UPDATE_INTERVAL 5.0

#define TMRHUD_XPOS 0.465
#define TMRHUD_YPOS 0.75
#define HOLD_INTERVAL 0.1

// Timer Hud Handle
Handle HUD_TimerDisplay = INVALID_HANDLE;
Handle H_Timer_Main = INVALID_HANDLE;

Handle H_Timer_Boxes = INVALID_HANDLE;

void ResetMainTimer()
{
	// Destroy the old Timer, Create a new one
	if (H_Timer_Main != INVALID_HANDLE)
		KillTimer(H_Timer_Main);
	H_Timer_Main = CreateTimer(UPDATE_INTERVAL, TMR_MainTick, _, TIMER_REPEAT);
	
	if (H_Timer_Boxes != INVALID_HANDLE)
		KillTimer(H_Timer_Boxes);
	H_Timer_Boxes = CreateTimer(TMR_BOX_UPDATE_INTERVAL, TMR_DrawBox, _, TIMER_REPEAT);
}

public Action TMR_MainTick(Handle timer, int data)
{
	static float EngTime;
	EngTime = GetEngineTime();
	
	static float TimeDiff;
	static int Target;
	// TODO User Defined Position?
	SetHudTextParams(TMRHUD_XPOS, TMRHUD_YPOS, HOLD_INTERVAL, 255, 255, 255, 10);
	for (int user = 1; user <= MaxClients; user++)
	{
		if (!IsClientInGame(user))continue;
		
		if (!IsClientObserver(user))
			Target = user;
		else
		{
			Target = GetEntPropEnt(user, Prop_Send, "m_hObserverTarget");
			if (Target <= 0 || Target > MaxClients)Target = user;
		}
		// Only False during late load
		if (USER_StartTime[Target] > 0.0)
		{
			TimeDiff = (USER_FinishTime[Target] <= 0 ? EngTime : USER_FinishTime[Target]) - USER_StartTime[Target];
		}
		ClearSyncHud(user, HUD_TimerDisplay);
		// Display Time if we Can
		if (USER_StartTime[Target] > 0.0)
		{
			ShowSyncHudText(user, HUD_TimerDisplay, "%s", FloatTimeToString(TimeDiff));
		}
	}
}

//TODO Implement This
public Action TMR_DrawBox(Handle timer, int data)
{
	for (int user = 1; user <= MaxClients; user++)
	{
		if (!IsClientInGame(user))continue;
		
		// Need to Calculate the Box Zones.
		// Need to Calculate the Box Zones.
		// Need to Calculate the Box Zones.
		// Need to Calculate the Box Zones.
	}
} 