/*
    MenuManager-UI.ms
    Launcher version: 1.11
    Project version: 1.18
    Configurable macroscript and quad-menu sources.
    Source lists are stored beside this launcher in MenuManager-UI.ini.
*/

/* Bind imported UI symbols globally before nested fileIn calls from loader functions.
   The launcher and its dependency files must reference the same persistent objects.
*/
global MenuManagerUI_ROLLOUT
global MenuManagerSourceSettings
global MENU_MANAGER_GLOBAL
global MenuManagerUICallbacks
global MenuManagerUILauncherPath
global MenuManagerProjectVersion
global menu_manager_launcher_file_version = 1.11
global menu_manager_launcher_project_version = 1.18

if MenuManagerProjectVersion == undefined or menu_manager_launcher_project_version > MenuManagerProjectVersion then
(
    MenuManagerProjectVersion = menu_manager_launcher_project_version
)

MenuManagerUILauncherPath = getSourceFileName()
if MenuManagerUILauncherPath == undefined or MenuManagerUILauncherPath == "" then
(
    throw "Menu Manager: run the saved MenuManager-UI.ms file to resolve its tool directory."
)

global menu_manager_ui_root_directory = getFilenamePath MenuManagerUILauncherPath

/* Load only the canonical shared UI helpers from the configured Google Drive.
   The same UI framework is used by other 3ds Max tools.
*/
function loadMenuManagerUiFramework =
(
    local framework_directories = #(
        "G:\\AI\\AGENTS\\Maxscript\\UI\\Default\\",
        "C:\\GoogleDrive\\AI\\AGENTS\\Maxscript\\UI\\Default\\",
        "D:\\GoogleDrive\\AI\\AGENTS\\Maxscript\\UI\\Default\\"
    )
    local framework_directory = ""

    for candidate_directory in framework_directories do
    (
        if framework_directory == "" and doesFileExist (candidate_directory + "ToolTitleButton.ms") then
            framework_directory = candidate_directory
    )

    if framework_directory == "" then
        throw "Menu Manager: shared MaxScript UI helpers were not found under AI\\AGENTS\\Maxscript\\UI\\Default."

    for helper_filename in #("IniSettings.ms", "RolloutState.ms", "DialogHost.ms", "ScriptReload.ms", "ToolTitleButton.ms") do
    (
        local helper_path = framework_directory + helper_filename
        if not doesFileExist helper_path then
            throw ("Menu Manager: missing shared UI helper: " + helper_path)

        fileIn helper_path
    )

    true -- return
)

loadMenuManagerUiFramework()
DialogHost.destroyToolDialogs "MenuManagerUI"
DialogHost.unregisterDockableDialog MenuManagerUI_ROLLOUT
try (destroyDialog MenuManagerUI_ROLLOUT) catch()

filein (menu_manager_ui_root_directory + "include-MenuManager.ms")

/* Always reload the current UI source even if the manager is already defined. */
filein (menu_manager_ui_root_directory + "MenuManagerUI/MenuManagerUI.ms")

/* Load persisted source lists before opening the manager UI. */
MenuManagerSourceSettings.ini_file_path = menu_manager_ui_root_directory + "MenuManager-UI.ini"
MenuManagerSourceSettings.loadSources()
MenuManagerSourceSettings.applySources()

/* Open the floatable left/right-dockable UI with persisted position and height. */
DialogHost.createManagedDialog MenuManagerUI_ROLLOUT MenuManagerSourceSettings.ini_file_path "MenuManagerUI" \
    tool_key:"MenuManagerUI" default_width:576 default_height:720 min_height:320
windows.processPostedMessages()

