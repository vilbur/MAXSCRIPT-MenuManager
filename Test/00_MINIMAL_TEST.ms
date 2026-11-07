/* Run in 3ds Max 2026+ using Scripting > Run Script.
   Expected: _Custom-Menus > _MINIMAL_TEST > Test Action.
   Uses the shared cache/startup loader and preserves existing saved menus.
*/

macroScript MenuBuilderMinimalTestAction
category:"MenuBuilder Tests"
toolTip:"Test Menu Builder"
buttonText:"Test Action"
(
	on execute do messageBox "Menu Builder action works." title:"Minimal Menu Test"
)

fileIn (getFilenamePath (getSourceFileName()) + "../Lib/MenuBuildManager/MenuBuildManager.ms")

MenuBuildManager = MenuBuildManager_v compile_mode:#PRODUCTION merge_existing_data:true

(
	local test_menu = MenuBuildManager.menu "_MINIMAL_TEST" type:#menu load_native_items:false
	test_menu.addItem "MenuBuilder Tests" "MenuBuilderMinimalTestAction" title:"Test Action"
	MenuBuildManager.installMenusNow save_cui_configuration:false update_quads:false
)

format "Minimal test: open _Custom-Menus > _MINIMAL_TEST > Test Action.\n"
