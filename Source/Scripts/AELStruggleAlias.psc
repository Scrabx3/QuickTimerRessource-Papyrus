Scriptname AELStruggleAlias extends ReferenceAlias  

float Property DefaultDuration = 8.0 AutoReadOnly

ReferenceAlias Property VictimAlias Auto
Static Property xMarker Auto

String[] anim_leadin
String[] anim_instant
String[] anim_breakfree

Actor _victim
String _callback
bool _victorious

int create_callback
bool Function Create(Actor akAggressor, Actor akVictim, String asCallback, float afDifficulty = 0.0, float afDuration = 0.0)
  If(!DefineAnimations(akAggressor))
    Debug.Trace("[AEL] No struggle animation for actor [" + akAggressor + "]", 1)
    return false
  EndIf
  _callback = asCallback
  _victim = akVictim
  ForceRefTo(akAggressor)
  Restrain(akAggressor, true)
  Restrain(akVictim, true)
  akAggressor.StopCombat()
  akVictim.StopCombat()

  ObjectReference vehicle = akVictim.PlaceAtMe(xMarker)
  akAggressor.SetVehicle(vehicle)
  akVictim.SetVehicle(vehicle)
  Utility.Wait(0.1)
  ; Victim will be done translating before aggressor
  create_callback = -1
  akAggressor.TranslateToRef(vehicle, 250.0)
  akVictim.TranslateToRef(vehicle, 250.0)
  If(akAggressor.IsSneaking())
    akAggressor.StartSneaking()
  EndIf
  If(akVictim.IsSneaking())
    akVictim.StartSneaking()
  EndIf
  While(create_callback == -1)
    Utility.Wait(0.1)
  EndWhile
  If(create_callback == 2)
    Restrain(akAggressor, false)
    Restrain(akVictim, false)
    akAggressor.SetVehicle(none)
    akVictim.SetVehicle(none)
    Clear()
    return false
  EndIf
  ; Victim & aggressor now on top of each other
  String[] anims = anim_instant
  If(!anims.Length || (anim_leadin.Length && akVictim.IsBleedingOut() || Acheron.IsDefeated(akVictim)))
    anims = anim_leadin
  EndIf
  Debug.SendAnimationEvent(akAggressor, anims[0])
  Debug.SendAnimationEvent(akVictim, anims[1])

  If(afDuration <= 0.025 && afDuration >= 0.0)
    Actor PlayerRef = Game.GetPlayer()
    If(akAggressor == PlayerRef || akVictim == PlayerRef)
      If(Acheron.OpenCustomMenu("AcheronEL\\AcheronQTE"))
        int handle = UICallback.Create("AcheronCustomMenu", "_root.main.beginGame")
        If(handle)
          UICallback.PushFloat(handle, afDifficulty)
          UICallback.PushBool(handle, Game.UsingGamepad())
          If(UICallback.Send(handle))
            RegisterForModEvent("AEL_GameEnd", "OnGameEnd")
            return true
          EndIf
        EndIf
      EndIf
      Debug.Messagebox("Failed to create flash game. Falling back to timed event")
    EndIf
    afDuration = DefaultDuration
  ElseIf(afDuration < 0)
    return true
  EndIf
  _victorious = Utility.RandomFloat(0, 99.9) < afDifficulty
  RegisterForSingleUpdate(afDuration)
  return true
EndFunction

Event OnTranslationComplete()
  create_callback = 1
EndEvent
Event OnTranslationFailed()
  create_callback = 2
EndEvent

Event OnGameEnd(string asEventName, string asStringArg, float afNumArg, form akSender)
  UnregisterForModEvent("AEL_GameEnd")
  bool player_won = afNumArg > 0
  If(_victim == Game.GetPlayer())
    _victorious = player_won
  Else
    _victorious = !player_won
  EndIf
  MakeEventAndClose()
EndEvent

Event OnUpdate()
  MakeEventAndClose()
EndEvent

Event OnCellDetach()
  MakeEventAndClose()
EndEvent

Function MakeEventAndClose()
  Actor aggressor = GetReference() as Actor
  If(_victorious)
    If(anim_breakfree.Length)
      Debug.SendAnimationEvent(_victim, anim_breakfree[0])
      Debug.SendAnimationEvent(aggressor, anim_breakfree[1])
      Utility.Wait(2.3)
    Else
      Debug.SendAnimationEvent(_victim, "IdleForceDefaultState")
      Debug.SendAnimationEvent(aggressor, "StaggerStart")
    EndIf
    String rt = Acheron.GetRaceType(aggressor)
    If(rt == "Human")
      ; nothing
    ElseIf(rt == "Skeever" || rt == "Wolf")
      _victim.PushActorAway(aggressor, 5.00000)
    ElseIf(rt == "Riekling" || rt == "DwarvenSpider")
      _victim.PushActorAway(aggressor, 3.50000)
    ElseIf(rt == "FrostbiteSpider" || rt == "Falmer" || rt == "Draugr")
      _victim.PushActorAway(aggressor, 2.00000)
    ElseIf(rt == "Sabrecat" || rt == "Gargoyle")
      _victim.PushActorAway(aggressor, 1.00000)
    ElseIf(rt == "Bear" || rt == "Werewolf" || rt == "Chaurus" || rt == "ChaurusReaper" || rt == "ChaurusHunter")
      _victim.PushActorAway(aggressor, 0.500000)
    Else ; If(rt == "Troll" || rt == "Giant")
      _victim.PushActorAway(aggressor, 0.200000)
    EndIf
  Else
    Debug.SendAnimationEvent(_victim, "StaggerStart")
    Debug.SendAnimationEvent(aggressor, "IdleForceDefaultState")
  EndIf
  Restrain(aggressor, false)
  Restrain(_victim, false)
  aggressor.SetVehicle(none)
  _victim.SetVehicle(none)
  Clear()

  int handle = ModEvent.Create(_callback)
  ModEvent.PushForm(handle, _victim)
  ModEvent.PushForm(handle, aggressor)
  ModEvent.PushBool(handle, _victorious)
  ModEvent.Send(handle)
EndFunction

Function Restrain(Actor akActor, bool abRestrain)
  If(akActor == Game.GetPlayer())
    Game.SetPlayerAIDriven(abRestrain)
  Else
    akActor.SetRestrained(abRestrain)
  EndIf
EndFunction

bool Function DefineAnimations(Actor akAggressor)
  String type = Acheron.GetRaceType(akAggressor)
  int file = JValue.zeroLifetime(JValue.readFromFile("Data\\SKSE\\AcheronEL\\Assault.json"))
  int root = JMap.getObj(file, type)
  anim_leadin = jObjToArray(root, "LeadIn")
  anim_instant = jObjToArray(root, "Instant")
  anim_breakfree = jObjToArray(root, "Breakfree")
  return anim_leadin.Length || anim_instant.Length
EndFunction
String[] Function jObjToArray(int root, String attribute)
  int jobj = JMap.getObj(root, attribute)
  If(!jobj)
    return Utility.CreateStringArray(0)
  EndIf
  return JArray.asStringArray(jobj)
EndFunction


Function ForceRefTo(ObjectReference akNewRef)
  Parent.ForceRefTo(akNewRef)
  VictimAlias.ForceRefTo(_victim)
EndFunction

Function Clear()
  Parent.Clear()
  VictimAlias.Clear()
EndFunction
