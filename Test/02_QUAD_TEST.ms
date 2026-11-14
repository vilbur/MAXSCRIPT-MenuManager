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
	
		
		
		/*------ BOTTOM RIGHT QUAD ------*/
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
Copy the complete Snap quadrant into the supplied quadrant.
*/
function configQuad2 QuadMenu =
(
	QuadMenu.setTitle "REPLACE QUAD"

	local snap_quad_menu = MenuDefinition_v type:#quad title:"Snap" data:#() manager:(MENU_MANAGER_GLOBAL.MenuBuildManager)
	local source_quad = snap_quad_menu.getExistingQuad #BottomRight
	if source_quad == undefined then throw "02_QUAD_TEST: Snap Bottom Right is unavailable."

	QuadMenu.addMenu source_quad flat:true
)

/*
Select Top Left from the root quad and copy the complete Snap quadrant into it.
*/
function configQuad3 QuadMenu =
(
	local target_quad = QuadMenu.getQuad #TopLeft
	target_quad.setTitle "REPLACE QUAD TARGET"

	local snap_quad_menu = MenuDefinition_v type:#quad title:"Snap" data:#() manager:(MENU_MANAGER_GLOBAL.MenuBuildManager)
	local source_quad = snap_quad_menu.getExistingQuad #BottomRight
	if source_quad == undefined then throw "02_QUAD_TEST: Snap Bottom Right is unavailable."

	target_quad.addMenu source_quad flat:true
)

/*
Copy only Vertex into the supplied quadrant.
*/
function configQuad4 QuadMenu =
(
	QuadMenu.setTitle "MOVE QUAD ITEMS"

	local snap_quad_menu = MenuDefinition_v type:#quad title:"Snap" data:#() manager:(MENU_MANAGER_GLOBAL.MenuBuildManager)
	local source_quad = snap_quad_menu.getExistingQuad #BottomRight
	if source_quad == undefined then throw "02_QUAD_TEST: Snap Bottom Right is unavailable."

	local vertex_item = source_quad.getItem "Vertex"
	if vertex_item == undefined then throw "02_QUAD_TEST: Vertex is missing from Snap Bottom Right."

	QuadMenu.clearItems()
	QuadMenu.addItemData vertex_item
)


/*==============================================================================

	RUN TESTS

================================================================================*/


/* DEFINE MENUS */ 
defineMenusItemsTest()


/* DEFINE QUADS */ 
defineQuadItemsTest()

/* USE EXISTING NATIVE QUAD */
test_quad = MENU_MANAGER_GLOBAL.quad "_TEST_QUAD"
configQuad2 (test_quad.getQuad #TopRight)
configQuad3 test_quad
configQuad4 (test_quad.getQuad #BottomLeft)


/*------------------------------------------------------------------------------
	CREATE MENUS
--------------------------------------------------------------------------------*/
		
/* CREATE MENUS */ 
MENU_MANAGER_GLOBAL.createMenus()


/* CREATE QUAD MENUS */ 
MENU_MANAGER_GLOBAL.createQuadMenus()


/* SUCCESS MESSAGE */ 
messageBox "Show quad by pressing:\n\nCTRL + RMB" title:"SHOW QUAD MENU"


