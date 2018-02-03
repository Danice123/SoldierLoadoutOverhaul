QoL overhaul of the loadout screen. 

First:
Adds categories for each slot, as an intermediate step to getting the list of equipment. The categories are based on weapon/item type, and are completely configurable from the ini file. There is also an 'other' tab, which will collect any item that doesn't fit into a category. You can also ignore slots, and they will work the same as the vanilla loadout. For the players out there that wish to micro manage their categories, you can make entries in the config file with the item name and new category, and they will be sorted correctly.

Second:
Removed the 'strip' buttons and instead allowed the player to see all weapons, equipped or not. If the player attempts to equip a weapon that is already equipped by another soldier, the weapon will be moved from one soldier to another, and the original soldier will have it's loadout stripped.

Overrides UIArmory_Loadout and is not compatible with any mod that also overrides this. The override should be Highlander compliant, so hooking into the class should work fine.

If you are not seeing images, delete/backup your XComArmory_Overhaul.ini file and then run the game, it will regenerate the correct config with image paths added.