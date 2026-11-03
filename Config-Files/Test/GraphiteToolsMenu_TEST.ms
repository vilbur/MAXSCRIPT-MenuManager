/*
GraphiteToolsMenu_TEST.ms
File Version: 0.01
Project Version: 0.10

Targeted test for GraphiteToolsMenu native Ribbon action binding and split JSON generation.
*/

global GRAPHITE_TOOLS_MENU_TEST_PROJECT_VERSION

if GRAPHITE_TOOLS_MENU_TEST_PROJECT_VERSION == undefined then GRAPHITE_TOOLS_MENU_TEST_PROJECT_VERSION = 0.10
else if GRAPHITE_TOOLS_MENU_TEST_PROJECT_VERSION < 0.10 then GRAPHITE_TOOLS_MENU_TEST_PROJECT_VERSION = 0.10

/*
Load and build the current Graphite tools menu producer.
Leaves the generated menu installed for direct UI inspection.
*/
function partOfTest1 =
(
    source_directory = getFilenamePath (getSourceFileName())
    producer_path = source_directory + "..\\GraphiteToolsMenu.ms"

    format "PART 1: load producer: %\n" producer_path
    if doesFileExist producer_path then
    (
        filein producer_path
        format "PART 1 RESULT: producer loaded = %\n" (GraphiteToolsMenu != undefined)
    )
    else
    (
        format "PART 1 RESULT: FAIL - producer file is missing.\n"
    )
    true -- return
)

/*
Report exact native Action Item resolution status.
A clean install should resolve every intended Ribbon-backed command without ambiguity.
*/
function partOfTest2 =
(
    if GraphiteToolsMenu != undefined then
    (
        GraphiteToolsMenu.printReport()
        total_methods = GraphiteToolsMenu.bound_functions.count + GraphiteToolsMenu.unresolved_functions.count
        format "PART 2 RESULT: bound=% unresolved=% ambiguous=% total=% expected=92\n" GraphiteToolsMenu.bound_functions.count GraphiteToolsMenu.unresolved_functions.count GraphiteToolsMenu.ambiguous_functions.count total_methods
        format "PART 2 METHOD COUNT VALID: %\n" (total_methods == 92)
    )
    else
    (
        format "PART 2 RESULT: FAIL - GraphiteToolsMenu is undefined.\n"
    )
    true -- return
)

/*
Verify MenuBuilder generated the independent split JSON menu file.
Prints the exact expected path for inspection.
*/
function partOfTest3 =
(
    if GraphiteToolsMenu != undefined and MENU_MANAGER_GLOBAL != undefined then
    (
        json_path = MENU_MANAGER_GLOBAL.MenuBuildManager.getSplitJsonFilePathByTitle GraphiteToolsMenu.root_menu_title menu_type:#menu
        format "PART 3: split JSON path: %\n" json_path
        format "PART 3 RESULT: JSON exists = %\n" (doesFileExist json_path)
    )
    else
    (
        format "PART 3 RESULT: FAIL - menu producer or MenuBuilder is undefined.\n"
    )
    true -- return
)

clearListener()
partOfTest1()
partOfTest2()
partOfTest3()

format "\nTEST FINISHED. UI state is intentionally preserved.\n"
