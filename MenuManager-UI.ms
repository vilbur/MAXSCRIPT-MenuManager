/*
    MenuManager-UI.ms
    Launcher version: 1.08
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

global menu_manager_ui_root_directory = getFilenamePath (getSourceFileName())
filein (menu_manager_ui_root_directory + "include-MenuManager.ms")

/* Always reload the current UI source even if the manager is already defined. */
filein (menu_manager_ui_root_directory + "MenuManagerUI/MenuManagerUI.ms")

/* Load persisted source lists before opening the manager UI. */
MenuManagerSourceSettings.ini_file_path = menu_manager_ui_root_directory + "MenuManager-UI.ini"
MenuManagerSourceSettings.loadSources()
MenuManagerSourceSettings.applySources()

/* Open the existing menu manager UI. */
try (destroyDialog MenuManagerUI_ROLLOUT) catch()
createDialog MenuManagerUI_ROLLOUT
