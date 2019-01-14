#if defined _JUMPTIMER_Included
#endinput
#endif
#define _JUMPTIMER_Included

//TODO We should consider a Version Check to confirm consistancy between Plugins?

/**
 * ENUM to make Failure Conditions more consistent 
 */
enum EFailureType
{
	GENERIC_FAIL = 0, 
	OUT_OF_BOUNDS = 1, 
};

/* Different Types of Enums used by the Timer */
enum CPTypes
{
	CP_NORMAL = 0, 
	CP_BONUS = 1, 
	CP_OUTOFBOUNDS = 2
}

/* Supported Classes */
#define CLASS_COUNT 5
enum TimerClass
{
	SOL = 0,
	DEM = 1,
	CONC = 2,
	ENG = 3,
	PYRO = 4
}

#define WeaponCheckCount 3
char WeaponCheckNames[WeaponCheckCount][] =  { "Primary", "Secondary", "Melee" };
enum WeaponCheckTypes
{
	TFWeaponSlot_Primary:SlotPrimary,
	TFWeaponSlot_Secondary:SlotSecondary,
	TFWeaponSlot_Melee:SlotMelee
}

/**
 * Called when a Plugin wants JumpTimer to do Failure Checks,
 * No checks are made, and failure is assumed using EFailureType for message if no Message is provided.
 */
forward CheckFailure(int client, EFailureType reason, const char[] Message, int MsgLength);