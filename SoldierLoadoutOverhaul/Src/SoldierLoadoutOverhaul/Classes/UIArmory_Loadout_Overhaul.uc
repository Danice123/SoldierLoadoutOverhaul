class UIArmory_Loadout_Overhaul extends UIArmory_Loadout;

struct LockerCategoryItem
{
	var EInventorySlot Slot;
	var array<name> Types;
	var string CategoryName;
	var array<string> Images;
};
var CategoryOptions Options;

struct InventoryItem
{
	var StateObjectReference ItemRef;
	var bool isEquipped;
	var StateObjectReference EquippedUnitRef;
	var XComGameState_Item Item;
	var bool CanBeEquipped;
	var string DisabledReason;
};

struct CategoryOverride
{
	var name Item;
	var name Category;
};

var bool isCategoryView;
var LockerCategoryItem OpenCategory;
var LockerCategoryItem NullCategory;

// @Override PopulateData()
simulated function PopulateData()
{
	super.PopulateData();
	Options = new class'CategoryOptions';
	Options.Load();
}

// @Override MeetsDisplayRequirement(X2ItemTemplate ItemTemplate)
// Check if item is in the correct category to be added to the list
function bool MeetsDisplayRequirement(X2ItemTemplate ItemTemplate)
{
	local name TemplateCategory;
	local bool FitsInAnyCategory;
	local LockerCategoryItem Category;
	local array<LockerCategoryItem> Categories;

	Categories = Options.getCategories();

	// Get Category from item
	TemplateCategory = GetItemTemplateCategory(ItemTemplate);

	// Generate other category
	if (OpenCategory.CategoryName == "Other")
	{
		
		FitsInAnyCategory = false;
		foreach Categories(Category)
		{
			if (IsInCategory(TemplateCategory, Category)) FitsInAnyCategory = true;
		}
		if (!FitsInAnyCategory)
		{
			return super.MeetsDisplayRequirement(ItemTemplate);
		}
	}
	// Filter items by category
	if (OpenCategory != NullCategory)
	{
		if (!IsInCategory(TemplateCategory, OpenCategory)) return false;
	}
	// Filter otherwise
	return super.MeetsDisplayRequirement(ItemTemplate);
}

// UpdateLockerListCategories()
// Update list of categories
simulated function UpdateLockerListCategories()
{
	local EInventorySlot SelectedSlot;
	local LockerCategoryItem Category;
	local array<LockerCategoryItem> Categories;

	Categories = Options.getCategories();

	SelectedSlot = GetSelectedSlot();

	// set title according to selected slot
	// Issue #118
	LocTag.StrValue0 = class'CHItemSlot'.static.SlotGetName(SelectedSlot);
	//LocTag.StrValue0 = m_strInventoryLabels[SelectedSlot];
	MC.FunctionString("setRightPanelTitle", `XEXPAND.ExpandString(m_strLockerTitle));

	LockerList.ClearItems();

	foreach Categories(Category)
	{
		if (SelectedSlot == Category.Slot && isCategoryEquipable(Category))
		{
			UIArmory_LoadoutItem_Overhaul(LockerList.CreateItem(class'UIArmory_LoadoutItem_Overhaul')).InitLoadoutCategoryItem(Category, Category.CategoryName, Category.Images);
		}
	}

	// If we have an invalid SelectedIndex, just try and select the first thing that we can.
	// Otherwise let's make sure the Navigator is selecting the right thing.
	if(LockerList.SelectedIndex < 0 || LockerList.SelectedIndex >= LockerList.ItemCount)
		LockerList.Navigator.SelectFirstAvailable();
	else
	{
		LockerList.Navigator.SetSelected(LockerList.GetSelectedItem());
	}
	OnSelectionChanged(ActiveList, ActiveList.SelectedIndex);
}

// @Override OnItemClicked(UIList ContainerList, int ItemIndex)
// hijack list selection
simulated function OnItemClicked(UIList ContainerList, int ItemIndex)
{
	local EInventorySlot SelectedSlot;
	local UIArmory_LoadoutItem_Overhaul SelectedItem;
	local bool WeaponAvaliable;
	local array<EInventorySlot> CategoryWhitelist;

	CategoryWhitelist = Options.GetCategoryWhitelist();

	if(ContainerList != ActiveList) return;

	if(UIArmory_LoadoutItem(ContainerList.GetItem(ItemIndex)).IsDisabled)
	{
		SelectedItem = UIArmory_LoadoutItem_Overhaul(ContainerList.GetItem(ItemIndex));
		if (SelectedItem == none)
		{
			Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
			return;
		}
		else if (!SelectedItem.InventoryRef.isEquipped)
		{
			Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
			return;
		}
	}

	SelectedSlot = GetSelectedSlot();

	if(ContainerList == EquippedList)
	{
		if (CategoryWhitelist.Find(SelectedSlot) != INDEX_NONE)
		{
			// Load Category view
			isCategoryView = true;
			UpdateLockerListCategories();
		}
		else
		{
			// Ignored Category, set category to none and load all items in slot
			OpenCategory = NullCategory;
			UpdateLockerList();
		}
		ChangeActiveList(LockerList);
	}
	else
	{
		if (isCategoryView)
		{
			// Switch to weapon list view of category
			isCategoryView = false;
			OpenCategory = UIArmory_LoadoutItem_Overhaul(LockerList.GetSelectedItem()).Category;
			UpdateLockerList();
		}
		else
		{
			// Equip weapon, return to equipped list
			ChangeActiveList(EquippedList);
			WeaponAvaliable = true;

			SelectedItem = UIArmory_LoadoutItem_Overhaul(LockerList.GetSelectedItem());
			if (SelectedItem.InventoryRef.isEquipped)
			{
				WeaponAvaliable = UnequipItemFromPreviousOwner(SelectedItem.InventoryRef);
			}

			if(WeaponAvaliable && EquipItem(SelectedItem))
			{
				// Release soldier pawn to force it to be re-created when armor changes
				UpdateData(GetSelectedSlot() == eInvSlot_Armor);

				if(bTutorialJumpOut && Movie.Pres.ScreenStack.HasInstanceOf(class'UISquadSelect'))
				{
					OnCancel();
				}
			}
		
			if (EquippedList.SelectedIndex < 0)
			{
				EquippedList.SetSelectedIndex(0);
			}
		}
	}
}

// @Override OnCancel()
// Back Button
simulated function OnCancel()
{
	if(ActiveList == EquippedList)
	{
		// If we are in the tutorial and came from squad select when the medikit objective is active, don't allow backing out
		if (!Movie.Pres.ScreenStack.HasInstanceOf(class'UISquadSelect') || class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M5_EquipMedikit') != eObjectiveState_InProgress)
		{
			super.OnCancel(); // exits screen
		}
	}	
	else 
	{
		if (isCategoryView || OpenCategory == NullCategory)
		{
			ChangeActiveList(EquippedList);
			OnSelectionChanged(EquippedList, EquippedList.SelectedIndex);
		}
		else
		{
			// Load Category view
			isCategoryView = true;
			UpdateLockerListCategories();
		}
	}
}

// isCategoryEquipable(EInventorySlot Slot, name Category)
simulated function bool isCategoryEquipable(LockerCategoryItem Category)
{
	local X2SoldierClassTemplate SoldierClassTemplate;
	local int i;

	switch(Category.Slot)
	{
	case eInvSlot_PrimaryWeapon: break;
	case eInvSlot_SecondaryWeapon: break;
	default:
		return true;
	}

	if (Category.CategoryName == "Other")
		return true;

	SoldierClassTemplate = GetUnit().GetSoldierClassTemplate();

	for (i = 0; i < SoldierClassTemplate.AllowedWeapons.Length; ++i)
	{
		if (Category.Slot == SoldierClassTemplate.AllowedWeapons[i].SlotType && IsInCategory(SoldierClassTemplate.AllowedWeapons[i].WeaponType, Category))
			return true;
	}
	return false;
}

// GetItemTemplateCategory(X2ItemTemplate ItemTemplate)
simulated function name GetItemTemplateCategory(X2ItemTemplate ItemTemplate)
{
	local X2WeaponTemplate WeaponTemplate;
	local name TemplateCategory;
	local array<CategoryOverride> Overrides;
	local int i;

	Overrides = Options.GetCategoryOverrides();
	i = Overrides.Find('Item', ItemTemplate.DataName);
	if (i != INDEX_NONE)
	{
		return Overrides[i].Category;
	}

	TemplateCategory = ItemTemplate.ItemCat;
	if (ItemTemplate.ItemCat == 'weapon')
	{
		WeaponTemplate = X2WeaponTemplate(ItemTemplate);
		if (WeaponTemplate != none)
		{
			TemplateCategory = WeaponTemplate.WeaponCat;
		}
	}
	return TemplateCategory;
}

// IsInCategory(name Item, LockerCategoryItem Category)
simulated function bool IsInCategory(name Item, LockerCategoryItem Category)
{
	local name n;
	local EInventorySlot SelectedSlot;

	SelectedSlot = GetSelectedSlot();

	foreach Category.Types(n)
	{
		if (Item == n && Category.Slot == SelectedSlot) return true;
	}
	return false;
}

// @Override
// UpdateLockerList()
simulated function UpdateLockerList()
{
	local EInventorySlot SelectedSlot;
	local array<InventoryItem> Inventory;
	local InventoryItem InventoryRef;
	local array<InventoryItem> LockerItems;
	local InventoryItem LockerItem;
	local UIArmory_LoadoutItem_Overhaul LoadoutItem;

	SelectedSlot = GetSelectedSlot();

	// set title according to selected slot
	// Issue #118
	LocTag.StrValue0 = class'CHItemSlot'.static.SlotGetName(SelectedSlot);
	//LocTag.StrValue0 = m_strInventoryLabels[SelectedSlot];
	MC.FunctionString("setRightPanelTitle", `XEXPAND.ExpandString(m_strLockerTitle));

	GetFullInventory(Inventory);
	foreach Inventory(InventoryRef)
	{
		InventoryRef.Item = GetItemFromHistory(InventoryRef.ItemRef.ObjectID);
		if(ShowInLockerList(InventoryRef.Item, SelectedSlot))
		{
			InventoryRef.DisabledReason = GetDisabledReason(InventoryRef.Item, SelectedSlot);
			InventoryRef.CanBeEquipped = InventoryRef.DisabledReason == ""; // sorting optimization
			if (InventoryRef.isEquipped)
			{
				InventoryRef.DisabledReason = "Equipped"; // Localize
			}
			LockerItems.AddItem(InventoryRef);
		}
	}

	LockerList.ClearItems();

	LockerItems.Sort(SortLockerListByUpgrades_Overhaul);
	LockerItems.Sort(SortLockerListByTier_Overhaul);
	LockerItems.Sort(SortLockerListByEquip_Overhaul);

	foreach LockerItems(LockerItem)
	{
		if (LockerItem.isEquipped && ((LockerItem.Item.GetMyTemplate().bInfiniteItem || LockerItem.Item.GetMyTemplate().StartingItem) && !LockerItem.Item.HasBeenModified()))
		{
			// Do nothing
		}
		else
		{
			LoadoutItem = UIArmory_LoadoutItem_Overhaul(LockerList.CreateItem(class'UIArmory_LoadoutItem_Overhaul'));
			LoadoutItem.InitLoadoutItem(LockerItem.Item, SelectedSlot, false, LockerItem.DisabledReason);
			LoadoutItem.InventoryRef = LockerItem;
			if (LockerItem.isEquipped)
			{
				LoadoutItem.SetCount(1);
				LoadoutItem.SetDisabled(true);
			}
		}
	}
	// If we have an invalid SelectedIndex, just try and select the first thing that we can.
	// Otherwise let's make sure the Navigator is selecting the right thing.
	if(LockerList.SelectedIndex < 0 || LockerList.SelectedIndex >= LockerList.ItemCount)
		LockerList.Navigator.SelectFirstAvailable();
	else
	{
		LockerList.Navigator.SetSelected(LockerList.GetSelectedItem());
	}
	OnSelectionChanged(ActiveList, ActiveList.SelectedIndex);
}

// GetFullInventory(out array<InventoryItem> Inventory)
function GetFullInventory(out array<InventoryItem> Inventory)
{
	local StateObjectReference ItemRef;
	local InventoryItem InventoryRef;
	local array<XComGameState_Unit> Soldiers;
	local XComGameState_Unit Soldier;

	// Get availiable inventory
	foreach class'UIUtilities_Strategy'.static.GetXComHQ().Inventory(ItemRef)
	{
		InventoryRef.ItemRef = ItemRef;
		Inventory.AddItem(InventoryRef);
	}

	Soldiers = class'UIUtilities_Strategy'.static.GetXComHQ().GetSoldiers(false, true);
	foreach  Soldiers(Soldier)
	{
		if(Soldier.ObjectID != GetUnitRef().ObjectID)
		{
			foreach Soldier.InventoryItems(ItemRef)
			{
				InventoryRef.ItemRef = ItemRef;
				InventoryRef.isEquipped = true;
				InventoryRef.EquippedUnitRef = Soldier.GetReference();
				Inventory.AddItem(InventoryRef);
			}
		}
	}
}

// SortLockerListByEquip_Overhaul(InventoryItem A, InventoryItem B)
simulated function int SortLockerListByEquip_Overhaul(InventoryItem A, InventoryItem B)
{
	if(A.CanBeEquipped && !B.CanBeEquipped) return 1;
	else if(!A.CanBeEquipped && B.CanBeEquipped) return -1;
	else return 0;
}

// SortLockerListByTier_Overhaul(InventoryItem A, InventoryItem B)
simulated function int SortLockerListByTier_Overhaul(InventoryItem A, InventoryItem B)
{
	local int TierA, TierB;

	TierA = A.Item.GetMyTemplate().Tier;
	TierB = B.Item.GetMyTemplate().Tier;

	if (TierA > TierB) return 1;
	else if (TierA < TierB) return -1;
	else return 0;
}

// SortLockerListByUpgrades_Overhaul(InventoryItem A, InventoryItem B)
simulated function int SortLockerListByUpgrades_Overhaul(InventoryItem A, InventoryItem B)
{
	local int UpgradesA, UpgradesB;

	UpgradesA = A.Item.GetMyWeaponUpgradeTemplates().Length;
	UpgradesB = B.Item.GetMyWeaponUpgradeTemplates().Length;

	if (UpgradesA > UpgradesB)
	{
		return 1;
	}
	else if (UpgradesA < UpgradesB)
	{
		return -1;
	}
	else
	{
		return 0;
	}
}

// UnequipItemFromPreviousOwner(InventoryItem InventoryRef)
simulated function bool UnequipItemFromPreviousOwner(InventoryItem InventoryRef)
{
	local XComGameState NewGameState;
	local XComGameState_Unit UnitState, UpdatedUnit;
	local array<EInventorySlot> SlotsToClear;

	class'CHItemSlot'.static.CollectSlots(class'CHItemSlot'.const.SLOT_ALL, SlotsToClear);

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(InventoryRef.EquippedUnitRef.ObjectID));
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Unequip Item");
	UpdatedUnit = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

	UpdatedUnit.MakeItemsAvailable(NewGameState, false, SlotsToClear);
	`GAMERULES.SubmitGameState(NewGameState);

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(InventoryRef.EquippedUnitRef.ObjectID));
	return UnitState.InventoryItems.Find('ObjectID', InventoryRef.ItemRef.ObjectID) == INDEX_NONE;
}

// @Override UpdateNavHelp()
simulated function UpdateNavHelp()
{
	// bsg-jrebar (4/26/17): Armory UI consistency changes, centering buttons, fixing overlaps
	// Adding super class nav help calls to this class so help can be made vertical
	local int i;
	local string PrevKey, NextKey;

	if(bUseNavHelp)
	{
		NavHelp.ClearButtonHelp();
		NavHelp.bIsVerticalHelp = `ISCONTROLLERACTIVE;

		if (CanCancel())
		{
			NavHelp.AddBackButton(OnCancel);
		}

		NavHelp.AddSelectNavHelp(); // bsg-jrebar (4/12/17): Moved Select Nav Help
		
		if(XComHQPresentationLayer(Movie.Pres) != none)
		{
			LocTag = XGParamTag(`XEXPANDCONTEXT.FindTag("XGParam"));
			LocTag.StrValue0 = Movie.Pres.m_kKeybindingData.GetKeyStringForAction(PC.PlayerInput, eTBC_PrevUnit);
			PrevKey = `XEXPAND.ExpandString(PrevSoldierKey);
			LocTag.StrValue0 = Movie.Pres.m_kKeybindingData.GetKeyStringForAction(PC.PlayerInput, eTBC_NextUnit);
			NextKey = `XEXPAND.ExpandString(NextSoldierKey);

			// Don't allow jumping to the geoscape from the armory in the tutorial or when coming from squad select
			if (class'XComGameState_HeadquartersXCom'.static.GetObjectiveStatus('T0_M7_WelcomeToGeoscape') != eObjectiveState_InProgress &&
				RemoveMenuEvent == '' && NavigationBackEvent == '' && !`ScreenStack.IsInStack(class'UISquadSelect'))
			{
				NavHelp.AddGeoscapeButton();
			}

			if( Movie.IsMouseActive() && IsAllowedToCycleSoldiers() && class'UIUtilities_Strategy'.static.HasSoldiersToCycleThrough(UnitReference, CanCycleTo) )
			{
				NavHelp.SetButtonType("XComButtonIconPC");
				i = eButtonIconPC_Prev_Soldier;
				NavHelp.AddCenterHelp( string(i), "", PrevSoldier, false, PrevKey);
				i = eButtonIconPC_Next_Soldier; 
				NavHelp.AddCenterHelp( string(i), "", NextSoldier, false, NextKey);
				NavHelp.SetButtonType("");
			}
		}

		if (`ISCONTROLLERACTIVE && 
			XComHQPresentationLayer(Movie.Pres) != none && IsAllowedToCycleSoldiers() && 
			class'UIUtilities_Strategy'.static.HasSoldiersToCycleThrough(UnitReference, CanCycleTo) &&
			//<bsg> 5435, ENABLE_NAVHELP_DURING_TUTORIAL, DCRUZ, 2016/06/23
			//INS:
			class'XComGameState_HeadquartersXCom'.static.IsObjectiveCompleted('T0_M2_WelcomeToArmory'))
			//</bsg>
		{
			NavHelp.AddCenterHelp(m_strTabNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_LBRB_L1R1); // bsg-jrebar (5/23/17): Removing inlined buttons
		}
		
		if( `ISCONTROLLERACTIVE )
			NavHelp.AddCenterHelp(m_strRotateNavHelp, class'UIUtilities_Input'.static.GetGamepadIconPrefix() $ class'UIUtilities_Input'.const.ICON_RSTICK); // bsg-jrebar (5/23/17): Removing inlined buttons
		// bsg-jrebar (5/3/17): end

		NavHelp.Show();
	}
	// bsg-jrebar (4/26/17): end
}