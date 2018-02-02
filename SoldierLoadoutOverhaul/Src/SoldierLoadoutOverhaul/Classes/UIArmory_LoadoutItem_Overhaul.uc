class UIArmory_LoadoutItem_Overhaul extends UIArmory_LoadoutItem dependson(UIArmory_Loadout_Overhaul);

var InventoryItem InventoryRef;
var LockerCategoryItem Category;

simulated function UIArmory_LoadoutItem InitLoadoutCategoryItem(LockerCategoryItem ItemCategory, string CategoryTitle, array<string> NewImages, optional string InitDisabledReason)
{
	InitPanel();

	SetInfinite(true);

	if (InitDisabledReason != "")
	{
		SetDisabled(true, class'UIUtilities_Text'.static.GetColoredText(InitDisabledReason, eUIState_Bad));
	}
	
	SetTitle(CategoryTitle);
	SetSubTitle("Category");
	SetImage(none); // TODO

	MC.FunctionVoid("clearIcons");

	Category = ItemCategory;
	SetCategoryImage(NewImages);

	return self;
}

simulated function SetCategoryImage(array<string> NewImages, optional bool needsMask)
{
	local int i;

	if(NewImages.Length == 0)
	{
		MC.FunctionVoid("setImages");
		return;
	}

	Images = NewImages;
		
	MC.BeginFunctionOp("setImages");
	MC.QueueBoolean(needsMask); // always first

	for( i = 0; i < Images.Length; i++ )
		MC.QueueString(Images[i]); 

	MC.EndOp();
}