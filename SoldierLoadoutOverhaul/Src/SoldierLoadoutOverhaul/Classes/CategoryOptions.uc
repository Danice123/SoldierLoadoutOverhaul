class CategoryOptions extends Object config(Armory_Overhaul) dependson(UIArmory_Loadout_Overhaul);

`include(SoldierLoadoutOverhaul/Src/SoldierLoadoutOverhaul/MCM_API_CfgHelpers.uci)

var config array<LockerCategoryItem> Categories;
var config array<EInventorySlot> CategoryWhitelist;
var config array<CategoryOverride> CategoryOverrides;
var config int CONFIG_VERSION;

`MCM_CH_VersionChecker(class'CategoryOptions_Defaults'.default.VERSION,CONFIG_VERSION)

function array<LockerCategoryItem> getCategories()
{
	return Categories;
}

function array<EInventorySlot> GetCategoryWhitelist()
{
	return CategoryWhitelist;
}

function array<CategoryOverride> GetCategoryOverrides()
{
	return CategoryOverrides;
}

function Load()
{
	Categories = `MCM_CH_GetValue(class'CategoryOptions_Defaults'.default.Categories,Categories);
	CategoryWhitelist = `MCM_CH_GetValue(class'CategoryOptions_Defaults'.default.CategoryWhitelist,CategoryWhitelist);
	CategoryOverrides = `MCM_CH_GetValue(class'CategoryOptions_Defaults'.default.CategoryOverrides,CategoryOverrides);
	CONFIG_VERSION = `MCM_CH_GetCompositeVersion();
    self.SaveConfig();
}