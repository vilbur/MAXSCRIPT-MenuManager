/*
    02_QUAD_TEST.ms
    File version: 0.03
    Project version: 1.29
*/

global MenuManagerProjectVersion
if MenuManagerProjectVersion == undefined then
(
    MenuManagerProjectVersion = 1.29
)
else if MenuManagerProjectVersion < 1.29 then
(
    MenuManagerProjectVersion = 1.29
)

clearListener(); print("Cleared in: "+getSourceFileName())

filein( getFilenamePath(getSourceFileName()) + "/../include-MenuManager.ms" )	--"./../include-MenuManager.ms"

filein( getFilenamePath(getSourceFileName()) + "/_INCLUDE-TEST_MACROSCRIPT.mcr" )	--"./_INCLUDE-TEST_MACROSCRIPT.mcr"



/*------------------------------------------------------------------------------
  
	TEST OF MENU AND QUAD MENUS using MenuManager_v

------------------------------------------------------------------------------*/

modifier_specs = #(
	#("None",	"None",	#nonePressed),
	#("Shift",	"Shift",	#shiftPressed),
	#("Ctrl",	"Ctrl",	#controlPressed),
	#("Alt",	"Alt",	#altPressed),
	#("ShiftCtrl",	"Shift+Ctrl",	#shiftAndControlPressed),
	#("ShiftAlt",	"Shift+Alt",	#shiftAndAltPressed),
	#("CtrlAlt",	"Ctrl+Alt",	#controlAndAltPressed),
	#("ShiftAltCtrl",	"Shift+Alt+Ctrl",	#shiftAndAltAndControlPressed)
)



/* CREATE INSTANCE FOR TESTING - FOR PRODUCTION CREATED IN "./../include-MenuManager.ms" */ 
global MENU_MANAGER_GLOBAL = MenuManager_v()


/* RESET MENUS AND QUAS */ 
MENU_MANAGER_GLOBAL.resetAll()

/* RESET MENUS */ 
MENU_MANAGER_GLOBAL.resetMenus() -- reset only menus

/* RESET QUADS */ 
MENU_MANAGER_GLOBAL.resetQuads() -- reset only quads


/*==============================================================================

	DEFINE MENUS

================================================================================*/


/** Add menus test
 */
function defineMenusItemsTest =
(
	--format "\n"; print ".createMenusTest()"
	
	for letter in #( "A", "B", "C") do 
	(
		menu_new = MENU_MANAGER_GLOBAL.menu ("_TEST_MENU_" + letter ) --type:#quad
	
		/* ADD ITEMS TO MENU */ 
		menu_new.addItem "_TEST_CATEGORY" "_test_macro" title:("ITEM 1 "+letter)
		
		menu_new.addItem "_TEST_CATEGORY" "_test_macro" title:("ITEM 2 "+letter)
	
		/* ADD NATIVE MAX ACTION */ 
		menu_new.addItem("Tools")("Hide Selection")	group:"Main UI" title:"Hide SELECTED"
		
	)
)



/*==============================================================================

	DEFINE QUAD MENUS

================================================================================*/  
	
/** Add quad items test
 */
function defineQuadItemsTest =
(
	--format "\n"; print ".defineQuadItemsTest()"
	
	--for modifier_spec in modifier_specs do 
	(
		quad_new = MENU_MANAGER_GLOBAL.quad ("_TEST_QUAD" ) --type:#quad
		
		quad_new.quad_modifier = #controlPressed
	
		
		
		/*------ BOTTOM LEFT QUAD ------*/
		quad_1 = quad_new.getQuad 1
	
		quad_1.addItem "_TEST_CATEGORY" "_test_macro" title:"ITEM 1 QUAD"
		quad_1.addSeparator()
		quad_1.addItem "_TEST_CATEGORY" "_test_macro" title:"TEST MACRO"
		
		
	
		/*------ TOP RIGHT QUAD ------*/
		quad_2 = quad_new.getQuad 2
	
		quad_2.setTitle "Custom Quad Title"
		
		quad_2.addMenu "_TEST_MENU_A" title:"MENU AS SUBMENU" separators:#(1,2) 
		
		quad_2.addSeparator()
		
		quad_2.addMenu "_TEST_MENU_B" flat:true
		
	)
)

/*==============================================================================

	USE EXISTING QUAD

================================================================================*/
/*
    Copy installed Snap Bottom Right items into the test quad's Top Left.
    getExistingQuad returns a populated native source without modifying Snap.
*/
function useExistingQuad =
(
	format "MenuBuildManager: %\n" MenuBuildManager
	local snap_quad_menu = MenuBuildManager.quad "Snap"
	local source_quad = snap_quad_menu.getExistingQuad #BottomRight
	format "SOURCE_QUAD: %\n" source_quad

	local quad_menu = MENU_MANAGER_GLOBAL.quad "_TEST_QUAD"
	local target_quad = quad_menu.getQuad #TopLeft
	target_quad.addMenu source_quad flat:true

	source_quad -- return
)


/*==============================================================================

	RUN TESTS

================================================================================*/


/* DEFINE MENUS */ 
defineMenusItemsTest()


/* DEFINE QUADS */ 
defineQuadItemsTest()

/* USE EXISTING NATIVE QUAD */
useExistingQuad()


/*------------------------------------------------------------------------------
	CREATE MENUS
--------------------------------------------------------------------------------*/
		
/* CREATE MENUS */ 
MENU_MANAGER_GLOBAL.createMenus()


/* CREATE QUAD MENUS */ 
MENU_MANAGER_GLOBAL.createQuadMenus()


/* SUCCESS MESSAGE */ 
messageBox "Show quad by pressing:\n\nCTRL + RMB" title:"SHOW QUAD MENU"


