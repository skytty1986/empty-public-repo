class AbilityBackgroundMusicComponent extends AbilityComponent
	editinlinenew
	hidecategories(Object)
	native;

var() MusicTrackStruct NewBackgroundMusic;
var() bool bStopActiveBackgroundMusic;


cpptext
{
	virtual struct BaseComponent* CreateCplusplusNode();
}


DefaultProperties
{
	LineColor=(R=0.7255,G=0.4784,B=0.3412,A=1.0)
	TitleString="BGMusic"
	bHaveTrail=true
	Duration=3.0
	bStopActiveBackgroundMusic=false
}

