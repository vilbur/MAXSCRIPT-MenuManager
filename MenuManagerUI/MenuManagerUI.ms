/*
	MenuManagerUI.ms
	Version: 1.24
	Project version: 1.25
	UI for MENU_MANAGER_GLOBAL macro management
	TreeView-based macroscript inspector + install/reset tools
*/

global MENU_MANAGER_GLOBAL
global MenuManagerUICallbacks
global MenuManagerProjectVersion
global MenuManagerUILauncherPath
global MenuManagerUIDialogTitle
global MenuManagerMacros_ROLLOUT
global MenuManagerQuads_ROLLOUT

/*
 * Selects a tab inside the Qt-based Menu Editor.
 * Returns true when the requested tab was selected.
 */
function selectMenuEditorTab menu_editor_handle tab_title =
(
    local tab_selected = false

    try
    (
        dotNet.loadAssembly "UIAutomationTypes"
        dotNet.loadAssembly "UIAutomationClient"

        local automation_element_class = dotNetClass "System.Windows.Automation.AutomationElement"
        local tree_scope_class = dotNetClass "System.Windows.Automation.TreeScope"
        local condition_class = dotNetClass "System.Windows.Automation.Condition"
        local selection_item_pattern_class = dotNetClass "System.Windows.Automation.SelectionItemPattern"

        local menu_editor_pointer = dotNetObject "System.IntPtr" menu_editor_handle
        local menu_editor_element = automation_element_class.FromHandle menu_editor_pointer
        local automation_elements = menu_editor_element.FindAll \
            tree_scope_class.Descendants \
            condition_class.TrueCondition

        if automation_elements.count > 0 then
        (
            for automation_index = 0 to automation_elements.count - 1 do
            (
                if tab_selected == false then
                (
                    local automation_element = automation_elements.item[automation_index]
                    local element_data = automation_element.Current

                    if element_data.Name == tab_title and element_data.ControlType.ProgrammaticName == "ControlType.TabItem" then
                    (
                        local selection_pattern = automation_element.GetCurrentPattern selection_item_pattern_class.Pattern
                        selection_pattern.Select()
                        tab_selected = true
                    )
                )
            )
        )
    )
    catch
    (
        format "Menu Editor tab selection failed: %\n" (getCurrentException())
    )

    tab_selected -- return
)

/*
 * Toggles or force-opens the Menu Editor.
 * tab_name: #none, #Menus or #Quads.
 */
function toggleMenuEditor force:false tab_name:#none =
(
    local menu_editor_hwnd = undefined
    local tab_title = undefined
    local tab_selected = false

    for editor_title in #("Menu Editor", "Menu Editor - Developer Mode") do
    (
        if menu_editor_hwnd == undefined then
            menu_editor_hwnd = windows.getChildHWND 0 editor_title parent:#max
    )

    if menu_editor_hwnd != undefined and force != true then
    (
        if menu_editor_hwnd[1] != undefined then
            windows.sendMessage menu_editor_hwnd[1] 0x0010 0 0

        menu_editor_hwnd = undefined
    )
    else
    (
        if menu_editor_hwnd == undefined then
        (
            actionMan.executeAction 0 "59246"

            for wait_index = 1 to 40 do
            (
                windows.processPostedMessages()
                sleep 0.05

                for editor_title in #("Menu Editor", "Menu Editor - Developer Mode") do
                (
                    if menu_editor_hwnd == undefined then
                        menu_editor_hwnd = windows.getChildHWND 0 editor_title parent:#max
                )

                if menu_editor_hwnd != undefined then exit
            )
        )

        tab_title = case tab_name of
        (
            #Menus: "Menus"
            #Quads: "Quads"
            default: undefined
        )

        if menu_editor_hwnd != undefined and tab_title != undefined then
        (
            for wait_index = 1 to 20 do
            (
                windows.processPostedMessages()
                tab_selected = selectMenuEditorTab menu_editor_hwnd[1] tab_title

                if tab_selected then exit
                sleep 0.05
            )

            if tab_selected == false then
                format "UI Automation tab \"%\" was not found.\n" tab_title
        )
    )

    menu_editor_hwnd -- return
)


struct MenuManagerUICallbacks_Struct
(
    version = 1.24,
    project_version = 1.25,

    function buildMacroTree paths treeView =
    (
        treeView.Nodes.Clear()

        for i = 1 to paths.count do
        (
            item = paths[i]
            if item == undefined then continue

            source_path = ""
            display_path = ""

            -- Handle both simple Strings and Objects with properties
            if classOf item == String then
            (
                source_path = item
                display_path = item
            )
            else
            (
                try (source_path = item.path) catch (source_path = "")
                try (display_path = item.name) catch (display_path = source_path)
            )

            parts = filterString display_path "\\/"

            -- Full source paths are stored on leaf nodes, but only the containing
            -- directory and filename are shown in the tree.
            if classOf item == String and parts.count >= 2 then
                parts = #(parts[parts.count - 1], parts[parts.count])
            
            -- Fallback in case filterString returns empty
            if parts.count == 0 then parts = #(display_path)

            currentCollection = treeView.Nodes
            node = undefined

            for p = 1 to parts.count do
            (
                part = parts[p]
                if part == "" then continue

                found = false

                for n = 0 to currentCollection.Count-1 do
                (
                    if currentCollection.Item[n].Text == part then
                    (
                        node = currentCollection.Item[n]
                        currentCollection = node.Nodes
                        found = true
                        exit
                    )
                )

                if found == false then
                (
                    node = currentCollection.Add(part)
                    currentCollection = node.Nodes
                )

                if p == parts.count and node != undefined then
                    node.Tag = source_path
            )
        )
    ),

    /* Return the prefix and suffix of a hyphenated menu title.
       Empty segments are not eligible for submenu grouping.
    */
    function getMacroMenuPrefixParts menu_title =
    (
        local title_parts = #()
        local title_text = menu_title as string
        local separator_index = findString title_text "-"

        if separator_index != undefined then
        (
            if separator_index > 1 and separator_index < title_text.count then
            (
                local prefix_text = trimRight (substring title_text 1 (separator_index - 1))
                local suffix_text = trimLeft (substring title_text (separator_index + 1) (title_text.count - separator_index))
                if prefix_text != "" and suffix_text != "" then
                    title_parts = #(prefix_text, suffix_text)
            )
        )

        title_parts -- return
    ),

    /* Group leaf menu nodes sharing a prefix at the same tree level.
       Keep each leaf's Tag unchanged for selecting and installing menus.
    */
    function groupMacroMenuTree nodes =
    (
        local prefix_counts = Dictionary #string
        local original_titles = #()

        if nodes.Count > 0 then
        (
            local existing_count = nodes.Count
            for node_index = 0 to existing_count - 1 do
            (
                local node = nodes.Item[node_index]
                appendIfUnique original_titles (node.Text as string)

                if node.Nodes.Count > 0 then
                (
                    this.groupMacroMenuTree node.Nodes
                )
                else if node.Tag != undefined then
                (
                    local prefix_parts = this.getMacroMenuPrefixParts node.Text
                    if prefix_parts.count == 2 then
                    (
                        local count_prefix = prefix_parts[1]
                        if not (HasDictValue prefix_counts count_prefix) then
                            prefix_counts[count_prefix] = 0
                        prefix_counts[count_prefix] = prefix_counts[count_prefix] + 1
                    )
                )
            )

            for prefix_text in prefix_counts.keys do
            (
                if prefix_counts[prefix_text] >= 2 and (findItem original_titles prefix_text) == 0 then
                (
                    local matching_nodes = #()
                    for node_index = 0 to nodes.Count - 1 do
                    (
                        local node = nodes.Item[node_index]
                        if node.Nodes.Count == 0 and node.Tag != undefined then
                        (
                            local node_parts = this.getMacroMenuPrefixParts node.Text
                            if node_parts.count == 2 and node_parts[1] == prefix_text then
                                append matching_nodes node
                        )
                    )

                    if matching_nodes.count >= 2 then
                    (
                        local new_group_node = nodes.Add prefix_text
                        for node in matching_nodes do
                        (
                            local node_parts = this.getMacroMenuPrefixParts node.Text
                            node.Remove()
                            node.Text = node_parts[2]
                            new_group_node.Nodes.Add node
                        )
                    )
                )
            )
        )

        nodes -- return
    ),

    /* Read installed menu and quad titles from the persisted menu data.
       Include menu titles nested under the custom main-menu root.
    */
    function getInstalledMenuNames =
    (
        local macro_titles = #()
        local quad_titles = #()

        if MENU_MANAGER_GLOBAL != undefined and (isProperty MENU_MANAGER_GLOBAL #MenuBuildManager) then
        (
            local build_manager = MENU_MANAGER_GLOBAL.MenuBuildManager
            if build_manager != undefined then
            (
                local saved_menu_data = #()
                try
                (
                    build_manager.invalidateSplitJsonCache()
                    saved_menu_data = build_manager.loadSavedMenusDataFromJson()
                )
                catch
                (
                    format "Menu Manager: cannot read installed menu data: %\n" (getCurrentException())
                )

                if classOf saved_menu_data == Array then
                (
                    for menu_data in saved_menu_data do
                    (
                        local menu_type = build_manager.getSavedMenuType menu_data
                        local menu_title = build_manager.getSavedMenuTitle menu_data

                        if menu_title != "" then
                        (
                            if menu_type == #menu or menu_type == #both then
                            (
                                if build_manager.isCustomMenuRootTitle menu_title then
                                (
                                    if HasDictValue menu_data #items then
                                    (
                                        local custom_menu_items = menu_data[#items]
                                        if classOf custom_menu_items == Array then
                                        (
                                            for custom_menu in custom_menu_items do
                                            (
                                                local child_title = build_manager.getSavedItemTitle custom_menu
                                                if child_title != "" then appendIfUnique macro_titles child_title
                                            )
                                        )
                                    )
                                )
                                else if not (build_manager.isMainMenuBarTitle menu_title) then
                                    appendIfUnique macro_titles menu_title
                            )

                            if menu_type == #quad or menu_type == #both then
                                appendIfUnique quad_titles menu_title
                        )
                    )
                )
            )
        )

        #(macro_titles, quad_titles) -- return
    ),

    /* Check installed leaves using their original menu IDs or quad filenames.
       Group nodes show checked only when every child is installed.
    */
    function setInstalledTreeChecks nodes installed_titles is_quad:false =
    (
        local all_children_checked = (nodes.Count > 0)

        for node_index = 0 to nodes.Count - 1 do
        (
            local node = nodes.Item[node_index]
            if node.Nodes.Count > 0 then
            (
                node.Checked = this.setInstalledTreeChecks node.Nodes installed_titles is_quad:is_quad
            )
            else
            (
                local menu_title = ""
                if node.Tag != undefined then
                (
                    menu_title = node.Tag as string
                    if is_quad then menu_title = "_" + (getFilenameFile menu_title)
                )
                node.Checked = (findItem installed_titles menu_title) > 0
            )

            if not node.Checked then all_children_checked = false
        )

        all_children_checked -- return
    ),

    function getSelectedMacro treeView =
    (
        try
        (
            node = treeView.SelectedNode
            if node != undefined then
            (
                -- If it is a leaf node, return its stored source value
                if node.Nodes.Count == 0 then
                (
                    if node.Tag != undefined then return node.Tag as string
                    return node.FullPath
                )
            )
        )
        catch()
        return undefined
    ),

    function setChildNodesChecked parent_node is_checked =
    (
        if parent_node != undefined and parent_node.Nodes.Count > 0 then
        (
            for child_index = 0 to parent_node.Nodes.Count - 1 do
            (
                child_node = parent_node.Nodes.Item[child_index]
                child_node.Checked = is_checked
                this.setChildNodesChecked child_node is_checked
            )
        )
    ),

    function collectVisibleNodes nodes visible_nodes =
    (
        if nodes.Count > 0 then
        (
            for node_index = 0 to nodes.Count - 1 do
            (
                local node = nodes.Item[node_index]
                append visible_nodes node
                if node.IsExpanded then
                    this.collectVisibleNodes node.Nodes visible_nodes
            )
        )

        visible_nodes -- return
    ),

    function findTreeNodeIndex nodes target_node =
    (
        local found_index = 0

        for node_index = 1 to nodes.count while found_index == 0 do
        (
            if nodes[node_index].Equals target_node then
                found_index = node_index
        )

        found_index -- return
    ),

    function isShiftKeyPressed =
    (
        local control_class = dotNetClass "System.Windows.Forms.Control"
        local modifier_text = control_class.ModifierKeys.ToString()

        findString modifier_text "Shift" != undefined -- return
    ),

    function setCheckedNodeRange tree_view first_node last_node is_checked =
    (
        local visible_nodes = #()
        this.collectVisibleNodes tree_view.Nodes visible_nodes

        local first_index = this.findTreeNodeIndex visible_nodes first_node
        local last_index = this.findTreeNodeIndex visible_nodes last_node

        if first_index == 0 or last_index == 0 then
        (
            last_node.Checked = is_checked
            this.setChildNodesChecked last_node is_checked
        )
        else
        (
            local range_start = first_index
            local range_end = last_index

            if range_start > range_end then
            (
                range_start = last_index
                range_end = first_index
            )

            for node_index = range_start to range_end do
            (
                local node = visible_nodes[node_index]
                node.Checked = is_checked
                this.setChildNodesChecked node is_checked
            )
        )
    ),

    function toggleNodeFromClick tree_view event_args selection_anchor =
    (
        local mouse_buttons = dotNetClass "System.Windows.Forms.MouseButtons"
        local hit_locations = dotNetClass "System.Windows.Forms.TreeViewHitTestLocations"
        local next_anchor = selection_anchor

        if event_args.Button == mouse_buttons.Left then
        (
            local hit_info = tree_view.HitTest event_args.Location
            local hit_location = hit_info.Location

            if hit_location != hit_locations.PlusMinus then
            (
                if this.isShiftKeyPressed() and selection_anchor != undefined then
                (
                    local is_checked = event_args.Node.Checked
                    if hit_location != hit_locations.StateImage then
                        is_checked = not event_args.Node.Checked

                    this.setCheckedNodeRange tree_view selection_anchor event_args.Node is_checked
                )
                else if hit_location != hit_locations.StateImage then
                (
                    local is_checked = not event_args.Node.Checked
                    event_args.Node.Checked = is_checked
                    this.setChildNodesChecked event_args.Node is_checked
                )

                next_anchor = event_args.Node
            )
        )

        next_anchor -- return
    ),

    function collectCheckedLeafPaths nodes selected_paths =
    (
        if nodes.Count > 0 then
        (
            for node_index = 0 to nodes.Count - 1 do
            (
                node = nodes.Item[node_index]
                if node.Nodes.Count > 0 then
                (
                    this.collectCheckedLeafPaths node.Nodes selected_paths
                )
                else if node.Checked and node.Tag != undefined then
                (
                    appendIfUnique selected_paths (node.Tag as string)
                )
            )
        )
        selected_paths -- return
    ),

    function getSelectedMacros treeView =
    (
        selected_paths = #()
        this.collectCheckedLeafPaths treeView.Nodes selected_paths

        -- Keep highlighted-node selection useful when no boxes are checked.
        if selected_paths.count == 0 then
        (
            selected_path = this.getSelectedMacro treeView
            if selected_path != undefined then append selected_paths selected_path
        )

        selected_paths -- return
    ),

    function getExistingSelectedPaths selected_paths =
    (
        existing_paths = #()
        missing_count = 0

        for source_path in selected_paths do
        (
            if doesFileExist source_path then
                appendIfUnique existing_paths source_path
            else
                missing_count += 1
        )

        if missing_count > 0 then
            messageBox ((missing_count as string) + " selected file(s) could not be found and were skipped.") title:"Menu Manager UI"

        existing_paths -- return
    ),

    function installMenusFromSelected selections =
    (
        try
        (
            if selections == undefined or selections.count == 0 then
            (
                messageBox "Check one or more menu names first." title:"Menu Manager UI"
            )
            else
            (
                MENU_MANAGER_GLOBAL.createMenus which:selections
                format "Installed % selected menu(s).\n" selections.count
            )
        )
        catch
        (
            this._showException()
        )
    ),

    function installQuadMenusFromSelected selections =
    (
        try
        (
            if selections == undefined or selections.count == 0 then
            (
                messageBox "Check one or more quad configuration files first." title:"Menu Manager UI"
            )
            else
            (
                selected_paths = this.getExistingSelectedPaths selections
                if selected_paths.count > 0 then
                (
                    selected_manager = MenuManager_v()
                    selected_manager.quadDir selected_paths
                    selected_manager.createQuadMenus()
                    format "Installed % selected quad configuration file(s).\n" selected_paths.count
                )
            )
        )
        catch
        (
            this._showException()
        )
    ),

    function resetMenus =
    (
        try
        (
            if MENU_MANAGER_GLOBAL == undefined or not (isProperty MENU_MANAGER_GLOBAL #resetMenus) then
            (
                messageBox "Menu manager is not available." title:"Menu Manager UI"
            )
            else if queryBox ("REMOVE NORMAL MENUS?\n\nQuad menus will be preserved.") title:"Reset Menus" beep:false then
            (
                format "Resetting normal menus. Please wait...\n"
                try (windows.processPostedMessages()) catch()
                MENU_MANAGER_GLOBAL.resetMenus()
                format "Finished resetting normal menus.\n"
            )
        )
        catch
        (
            this._showException()
            messageBox "Reset menus failed. See the MAXScript Listener for details." title:"Menu Manager UI"
        )
    ),

    function resetQuads =
    (
        try
        (
            if isProperty MENU_MANAGER_GLOBAL #resetQuads then
            (
                MENU_MANAGER_GLOBAL.resetQuads()
            )
        )
        catch()
    ),
	

	private
	
	/** Show exception
	 */
	function _showException =
	(
		format "\n"; print "MenuManagerUICallbacks_Struct._showException()"
		format "\n——————————————— ERROR IN FILE ———————————————\n\n%\n" (getSourceFileName())
		format "\n————————————————— EXCEPTION —————————————————\n\n%\n" (getCurrentException())
		format "\n——————————————————— TRACE ———————————————————\n%\n"   (getCurrentExceptionStackTrace())
		format "\n——————————————————— STACK ———————————————————\n%\n"   (getCurrentExceptionCallStack())
	),
	/**
	 */
	on create do
	(
		--format "\n"; print "MenuManagerUICallbacks_Struct.onCreate()"
	)
	
)

-- Initialize the global struct instance
MenuManagerUICallbacks = MenuManagerUICallbacks_Struct()
if MenuManagerProjectVersion == undefined then
(
    MenuManagerProjectVersion = MenuManagerUICallbacks.project_version
)
else if MenuManagerUICallbacks.project_version > MenuManagerProjectVersion then
(
    MenuManagerProjectVersion = MenuManagerUICallbacks.project_version
)

/* Resolve a persistent INI path beside the launcher when the UI lives in its
   MenuManagerUI subfolder, or beside this script otherwise.
*/
function getDefaultMenuManagerIniPath =
(
    local script_file = getSourceFileName()

    if script_file == undefined or script_file == "" then
    (
        format "Menu Manager: the script must be saved before its INI path can be resolved.\n"
        ""
    )
    else
    (
        local path_class = dotNetClass "System.IO.Path"
        local script_dir = path_class.GetDirectoryName script_file
        local script_dir_name = path_class.GetFileName script_dir

        if (toLower script_dir_name) == "menumanagerui" then
        (
            script_dir = path_class.GetDirectoryName script_dir
        )

        path_class.Combine script_dir "MenuManager-UI.ini" -- return
    )
)


/*
    Persist source files and folders for the Menu Manager UI.
    The launcher provides the INI location beside MenuManager-UI.ms.
*/
struct MenuManagerSourceSettings_v
(
    ini_file_path = "",
    macro_sources = #(),
    quad_sources = #(),

    /* Read one counted list of source paths from the settings file.
       Preserve ordering and ignore empty entries.
    */
    function readSourceList section_name =
    (
        local source_paths = #()
        local count_text = getINISetting this.ini_file_path section_name "Count"
        local source_count = 0

        if count_text != "" then source_count = count_text as integer
        if source_count < 0 then source_count = 0
        if source_count > 1024 then source_count = 1024

        for source_index = 1 to source_count do
        (
            local path_text = getINISetting this.ini_file_path section_name ("Path" + (source_index as string))
            if path_text != "" then appendIfUnique source_paths path_text
        )

        source_paths -- return
    ),

    /* Overwrite one counted INI list, checking every write for failure.
       The other settings section remains unchanged.
    */
    function writeSourceList section_name source_paths =
    (
        local old_count_text = getINISetting this.ini_file_path section_name "Count"
        local old_count = if old_count_text == "" then 0 else (old_count_text as integer)
        local saved_ok = true

        for source_index = 1 to old_count do
        (
            if (setINISetting this.ini_file_path section_name ("Path" + (source_index as string)) "") == false then
                saved_ok = false
        )

        if (setINISetting this.ini_file_path section_name "Count" (source_paths.count as string)) == false then
            saved_ok = false

        for source_index = 1 to source_paths.count do
        (
            if (setINISetting this.ini_file_path section_name ("Path" + (source_index as string)) source_paths[source_index]) == false then
                saved_ok = false
        )

        saved_ok -- return
    ),

    /* Compare persisted source lists with the submitted paths.
       Also detect a successful write that did not survive readback.
    */
    function sourceListsEqual expected_paths actual_paths =
    (
        local lists_equal = expected_paths.count == actual_paths.count

        if lists_equal then
        (
            for source_index = 1 to expected_paths.count do
            (
                if expected_paths[source_index] != actual_paths[source_index] then
                    lists_equal = false
            )
        )

        lists_equal -- return
    ),

    /* Load saved sources without changing the installed menu configuration.
       An empty file means the user has not configured any sources yet.
    */
    function loadSources =
    (
        if ini_file_path == undefined or ini_file_path == "" then
        (
            format "Menu Manager: missing settings path.\n"
            false
        )
        else
        (
            if doesFileExist ini_file_path then
            (
                this.macro_sources = this.readSourceList "Macroscripts"
                this.quad_sources = this.readSourceList "QuadConfigurations"
            )
            true
        ) -- return
    ),

    /* Save both source lists to the stable unversioned INI file.
       Store the full paths selected by the user.
    */
    function saveSources =
    (
        if ini_file_path == undefined or ini_file_path == "" then
        (
            format "Menu Manager: settings cannot be saved without an INI path.\n"
            false
        )
        else
        (
            local macros_saved = this.writeSourceList "Macroscripts" this.macro_sources
            local quads_saved = this.writeSourceList "QuadConfigurations" this.quad_sources
            local saved_ok = macros_saved and quads_saved

            if saved_ok then
            (
                saved_ok = (this.sourceListsEqual this.macro_sources (this.readSourceList "Macroscripts")) and \
                           (this.sourceListsEqual this.quad_sources (this.readSourceList "QuadConfigurations"))
            )

            if saved_ok == false then
                format "Menu Manager: could not save source paths to %\n" ini_file_path

            saved_ok -- return
        ) -- return
    ),

    /* Recreate the manager definitions from configured source paths.
       This updates the UI data only; installation remains an explicit action.
    */
    function applySources =
    (
        global MENU_MANAGER_GLOBAL
        MENU_MANAGER_GLOBAL = MenuManager_v()
        local valid_quad_sources = #()

        for source_path in this.macro_sources do
        (
            if doesDirectoryExist source_path then
            (
                local source_files = getFiles (pathConfig.appendPath source_path "*.mcr") recurse:true
                if source_files.count > 0 then MENU_MANAGER_GLOBAL.addMacrosToMenus source_files
            )
            else if doesFileExist source_path then
                MENU_MANAGER_GLOBAL.addMacrosToMenus source_path
            else
                format "Menu Manager: missing macroscript source: %\n" source_path
        )

        for source_path in this.quad_sources do
        (
            if doesDirectoryExist source_path then
            (
                local source_files = getFiles (pathConfig.appendPath source_path "*.ms")
                for quad_file in source_files do appendIfUnique valid_quad_sources quad_file
            )
            else if doesFileExist source_path then
                append valid_quad_sources source_path
            else
                format "Menu Manager: missing quad source: %\n" source_path
        )

        if valid_quad_sources.count > 0 then MENU_MANAGER_GLOBAL.quadDir valid_quad_sources

        true -- return
    ),

    on create do
    (
    )
)

global MenuManagerSourceSettings = MenuManagerSourceSettings_v()
MenuManagerSourceSettings.ini_file_path = getDefaultMenuManagerIniPath()

MenuManagerUIDialogTitle = "Menu Manager UI v" + (MenuManagerProjectVersion as string)

/* MacroScript source browsing and preview controls.
   This panel only displays menus parsed from the selected source.
*/
rollout MenuManagerMacros_ROLLOUT "MAXSCRIPTS" width:528 height:672 autoLayoutOnResize:false
(
    dotNetControl btnMenusEditor "System.Windows.Forms.Button" pos:[8,8] width:512 height:28
    label lblMacroSources "MACROSCRIPT SOURCES (.mcr files or folders)" pos:[8,48] width:512 height:18
    dotNetControl lstMacroSources "System.Windows.Forms.ListView" pos:[8,70] width:512 height:54
    button btnAddMacroFile "BROWSE FILE" pos:[8,130] width:168 height:24
    button btnAddMacroFolder "BROWSE FOLDER" pos:[184,130] width:168 height:24
    button btnRemoveMacro "REMOVE SELECTED" pos:[360,130] width:160 height:24
    label lblMacroTree "MACROSCRIPT MENUS" pos:[8,162] width:512 height:18
    dotNetControl tv_menus "System.Windows.Forms.TreeView" pos:[8,184] width:512 height:480
    button btnInstallMenus "INSTALL SELECTED" pos:[8,676] width:252 height:24
    button btnResetMenus "RESET MENUS" pos:[268,676] width:252 height:24

    local menu_selection_anchor = undefined

    on btnMenusEditor Click sender event_args do
    (
        toggleMenuEditor force:true tab_name:#Menus
    )

    on btnAddMacroFile pressed do
    (
        local source_path = getOpenFileName caption:"Choose macroscript" types:"Macroscripts (*.mcr)|*.mcr|"
        MenuManagerUI_ROLLOUT.addDraftSource source_path #macro
    )

    on btnAddMacroFolder pressed do
    (
        MenuManagerUI_ROLLOUT.addDraftSource (getSavePath caption:"Choose macroscript folder") #macro
    )

    on btnRemoveMacro pressed do
    (
        MenuManagerUI_ROLLOUT.removeDraftSource #macro
    )

    on lstMacroSources SelectedIndexChanged sender event_args do
    (
        MenuManagerUI_ROLLOUT.refreshMacroPreview()
    )

    on lstMacroSources MouseDoubleClick sender event_args do
    (
        if event_args.Button == (dotNetClass "System.Windows.Forms.MouseButtons").Left then
        (
            local clicked_item = sender.GetItemAt event_args.X event_args.Y
            if clicked_item != undefined then
            (
                clicked_item.Selected = true
                MenuManagerUI_ROLLOUT.relocateMissingMacroSource()
            )
        )
    )

    on btnInstallMenus pressed do
    (
        local selections = MenuManagerUICallbacks.getSelectedMacros tv_menus
        if selections.count > 0 then MenuManagerSourceSettings.applySources()
        MenuManagerUICallbacks.installMenusFromSelected selections
        MenuManagerUI_ROLLOUT.refreshInstalledStates()
    )

    on tv_menus NodeMouseClick sender event_args do
    (
        menu_selection_anchor = MenuManagerUICallbacks.toggleNodeFromClick sender event_args menu_selection_anchor
    )

    on tv_menus AfterCheck sender event_args do
    (
        local tree_view_action = dotNetClass "System.Windows.Forms.TreeViewAction"
        if event_args.Action != tree_view_action.Unknown then
            MenuManagerUICallbacks.setChildNodesChecked event_args.Node event_args.Node.Checked
    )

    on btnResetMenus pressed do
    (
        MenuManagerUICallbacks.resetMenus()
        MenuManagerUI_ROLLOUT.refreshInstalledStates()
    )

    on MenuManagerMacros_ROLLOUT rolledUp state do
    (
        if MenuManagerQuads_ROLLOUT.open == state then
            MenuManagerQuads_ROLLOUT.open = not state
        if state then MenuManagerUI_ROLLOUT.fitDialogToOpenRollout()
    )

)

/* Quad configuration browsing, selection and installation controls.
   Keeps quad management independent from the MacroScript preview.
*/
rollout MenuManagerQuads_ROLLOUT "QUAD MENUS" width:528 height:672 autoLayoutOnResize:false
(
    dotNetControl btnQuadsEditor "System.Windows.Forms.Button" pos:[8,8] width:512 height:28
    label lblQuadSources "QUAD CONFIG SOURCES (.ms files or folders)" pos:[8,48] width:512 height:18
    dotNetControl lstQuadSources "System.Windows.Forms.ListBox" pos:[8,70] width:512 height:54
    button btnAddQuadFile "BROWSE FILE" pos:[8,130] width:168 height:24
    button btnAddQuadFolder "BROWSE FOLDER" pos:[184,130] width:168 height:24
    button btnRemoveQuad "REMOVE SELECTED" pos:[360,130] width:160 height:24
    label lblQuadTree "QUAD MENUS" pos:[8,162] width:512 height:18
    dotNetControl tv_quads "System.Windows.Forms.TreeView" pos:[8,184] width:512 height:480
    button btnInstallQuads "INSTALL SELECTED" pos:[8,676] width:252 height:24
    button btnResetQuads "RESET QUADS" pos:[268,676] width:252 height:24

    local quad_selection_anchor = undefined

    on btnQuadsEditor Click sender event_args do
    (
        toggleMenuEditor force:true tab_name:#Quads
    )

    on btnAddQuadFile pressed do
    (
        local source_path = getOpenFileName caption:"Choose quad config" types:"MaxScript (*.ms)|*.ms|"
        MenuManagerUI_ROLLOUT.addDraftSource source_path #quad
    )

    on btnAddQuadFolder pressed do
    (
        MenuManagerUI_ROLLOUT.addDraftSource (getSavePath caption:"Choose quad configuration folder") #quad
    )

    on btnRemoveQuad pressed do
    (
        MenuManagerUI_ROLLOUT.removeDraftSource #quad
    )

    on btnInstallQuads pressed do
    (
        local selections = MenuManagerUICallbacks.getSelectedMacros tv_quads
        MenuManagerUICallbacks.installQuadMenusFromSelected selections
        MenuManagerUI_ROLLOUT.refreshInstalledStates()
    )

    on tv_quads NodeMouseClick sender event_args do
    (
        quad_selection_anchor = MenuManagerUICallbacks.toggleNodeFromClick sender event_args quad_selection_anchor
    )

    on tv_quads AfterCheck sender event_args do
    (
        local tree_view_action = dotNetClass "System.Windows.Forms.TreeViewAction"
        if event_args.Action != tree_view_action.Unknown then
            MenuManagerUICallbacks.setChildNodesChecked event_args.Node event_args.Node.Checked
    )

    on btnResetQuads pressed do
    (
        MenuManagerUICallbacks.resetQuads()
        MenuManagerUI_ROLLOUT.refreshInstalledStates()
    )

    on MenuManagerQuads_ROLLOUT rolledUp state do
    (
        if MenuManagerMacros_ROLLOUT.open == state then
            MenuManagerMacros_ROLLOUT.open = not state
        if state then MenuManagerUI_ROLLOUT.fitDialogToOpenRollout()
    )

)

rollout MenuManagerUI_ROLLOUT MenuManagerUIDialogTitle width:576 height:720
(
    dotNetControl btn_tool_title "System.Windows.Forms.Button" pos:[12,12] width:552 height:20
    subRollout sr_menu_sections "" pos:[12,48] width:552 height:596
    button btnSaveSources "SAVE & APPLY" pos:[12,652] width:180 height:24
    button btnRefresh "REFRESH" pos:[204,652] width:180 height:24
    label lblIniInfo "Paths save automatically. SAVE & APPLY updates menus." pos:[12,688] width:552 height:20

    local macro_data = #()
    local quad_data = #()
    local draft_macro_sources = #()
    local draft_quad_sources = #()
    local source_lists_dirty = false
    local macro_selection_refresh_suspended = false
    local auto_fit_ready = false
    local fit_tree_height = undefined

    /* Synchronize both TreeViews with menus persisted by MenuBuildManager.
       Re-read installed definitions after install, reset, or source refresh.
    */
    function refreshInstalledStates =
    (
        local installed_names = MenuManagerUICallbacks.getInstalledMenuNames()
        MenuManagerUICallbacks.setInstalledTreeChecks MenuManagerMacros_ROLLOUT.tv_menus.Nodes installed_names[1]
        MenuManagerUICallbacks.setInstalledTreeChecks MenuManagerQuads_ROLLOUT.tv_quads.Nodes installed_names[2] is_quad:true
        true -- return
    )

    /* Size the source list to its entries plus two blank rows, minimum four.
       Move the controls below it so a taller list cannot overlap the tree.
    */
    function layoutSourcePanel source_list browse_file_button browse_folder_button remove_button tree_label tree_view install_button reset_button tree_height is_macro_list:false =
    (
        local source_rows = source_list.Items.Count + 2
        if source_rows < 4 then source_rows = 4

        if is_macro_list then
        (
            source_list.Height = (source_rows * (source_list.Font.Height + 5)) + 4
        )
        else
        (
            source_list.IntegralHeight = false
            source_list.Height = (source_rows * source_list.ItemHeight) + 4
        )

        local browse_y = 70 + source_list.Height + 6
        local tree_label_y = browse_y + 32
        local tree_y = tree_label_y + 22
        local actions_y = tree_y + tree_height + 12

        browse_file_button.pos = [8, browse_y]
        browse_folder_button.pos = [184, browse_y]
        remove_button.pos = [360, browse_y]
        tree_label.pos = [8, tree_label_y]
        tree_view.pos = [8, tree_y]
        tree_view.height = tree_height
        install_button.pos = [8, actions_y]
        reset_button.pos = [268, actions_y]

        (actions_y + 24 + 12) -- return
    )

    /* Give both menu trees at least two-thirds of the main rollout height.
       Size source sections independently and keep the shared panel scrollable.
    */
    function updateTreeLayout =
    (
        local dialog_size = getDialogSize MenuManagerUI_ROLLOUT
        local dialog_height = if dialog_size != undefined then dialog_size.y else 720
        if dialog_height < 320 then dialog_height = 320

        local menu_tree_height = if fit_tree_height != undefined then fit_tree_height else (ceil ((dialog_height * 2.0) / 3.0)) as integer
        local footer_y = dialog_height - 68

        sr_menu_sections.height = dialog_height - 124
        MenuManagerMacros_ROLLOUT.height = layoutSourcePanel \
            MenuManagerMacros_ROLLOUT.lstMacroSources \
            MenuManagerMacros_ROLLOUT.btnAddMacroFile \
            MenuManagerMacros_ROLLOUT.btnAddMacroFolder \
            MenuManagerMacros_ROLLOUT.btnRemoveMacro \
            MenuManagerMacros_ROLLOUT.lblMacroTree \
            MenuManagerMacros_ROLLOUT.tv_menus \
            MenuManagerMacros_ROLLOUT.btnInstallMenus \
            MenuManagerMacros_ROLLOUT.btnResetMenus \
            menu_tree_height is_macro_list:true

        MenuManagerQuads_ROLLOUT.height = layoutSourcePanel \
            MenuManagerQuads_ROLLOUT.lstQuadSources \
            MenuManagerQuads_ROLLOUT.btnAddQuadFile \
            MenuManagerQuads_ROLLOUT.btnAddQuadFolder \
            MenuManagerQuads_ROLLOUT.btnRemoveQuad \
            MenuManagerQuads_ROLLOUT.lblQuadTree \
            MenuManagerQuads_ROLLOUT.tv_quads \
            MenuManagerQuads_ROLLOUT.btnInstallQuads \
            MenuManagerQuads_ROLLOUT.btnResetQuads \
            menu_tree_height

        btnSaveSources.pos = [12, footer_y]
        btnRefresh.pos = [204, footer_y]
        lblIniInfo.pos = [12, footer_y + 36]
    )

    /* Fit the dialog to the currently expanded menu panel.
       Keep the tree height fixed during programmatic resizing to avoid growth loops.
    */
    function fitDialogToOpenRollout =
    (
        if not auto_fit_ready then return false

        local dialog_size = getDialogSize MenuManagerUI_ROLLOUT
        if dialog_size == undefined then return false

        local panel_height = if MenuManagerMacros_ROLLOUT.open then MenuManagerMacros_ROLLOUT.height else MenuManagerQuads_ROLLOUT.height
        local target_height = (ceil (panel_height + 148)) as integer
        local screen_height_limit = target_height

        try
        (
            local screen_class = dotNetClass "System.Windows.Forms.Screen"
            local current_screen = screen_class.FromControl btn_tool_title
            local physical_dialog_size = getDialogSize MenuManagerUI_ROLLOUT removeUIScaling:false
            local ui_scale = 1.0
            if physical_dialog_size != undefined and dialog_size.y > 0 then
                ui_scale = (physical_dialog_size.y as float) / (dialog_size.y as float)
            if ui_scale <= 0 then ui_scale = 1.0
            screen_height_limit = (floor ((current_screen.WorkingArea.Height - 32) / ui_scale)) as integer
        )
        catch
        (
            format "Menu Manager: could not determine screen height: %\n" (getCurrentException())
        )

        if screen_height_limit < 320 then screen_height_limit = 320
        if target_height > screen_height_limit then target_height = screen_height_limit
        if target_height < 320 then target_height = 320

        if (abs (dialog_size.y - target_height)) > 1 then
        (
            fit_tree_height = MenuManagerMacros_ROLLOUT.tv_menus.height
            try
            (
                setDialogSize MenuManagerUI_ROLLOUT [dialog_size.x, target_height]
                updateTreeLayout()
            )
            catch
            (
                format "Menu Manager: could not fit dialog height: %\n" (getCurrentException())
            )
            fit_tree_height = undefined
        )

        true -- return
    )

    /* Read the current MacroScript ListView index; -1 means nothing selected.
       ListView exposes SelectedIndices rather than ListBox.SelectedIndex.
    */
    function getSelectedMacroSourceIndex =
    (
        local source_list = MenuManagerMacros_ROLLOUT.lstMacroSources
        local selected_index = -1
        if source_list.SelectedIndices.Count > 0 then
            selected_index = source_list.SelectedIndices.Item[0] as integer
        selected_index -- return
    )

    /* Find the closest existing directory to an old, possibly missing path.
       Start browsing as close as possible to the original source location.
    */
    function getExistingMacroBrowseDirectory old_path =
    (
        local path_class = dotNetClass "System.IO.Path"
        local browse_dir = if doesDirectoryExist old_path then old_path else (path_class.GetDirectoryName old_path)

        for ancestor_index = 1 to 32 do
        (
            if browse_dir == undefined or browse_dir == "" then exit
            if doesDirectoryExist browse_dir then exit
            local parent_dir = path_class.GetDirectoryName browse_dir
            if parent_dir == undefined or parent_dir == browse_dir then exit
            browse_dir = parent_dir
        )

        if browse_dir == undefined or browse_dir == "" or not (doesDirectoryExist browse_dir) then
            browse_dir = getDir #scripts
        browse_dir -- return
    )

    /* Browse a replacement for a missing .mcr file or source directory.
       Initialize the dialog using the old file/folder location where possible.
    */
    function browseMissingMacroSource old_path =
    (
        local replacement_path = undefined
        local dialog_result = dotNetClass "System.Windows.Forms.DialogResult"
        local path_class = dotNetClass "System.IO.Path"
        local initial_dir = getExistingMacroBrowseDirectory old_path

        if (toLower (getFilenameType old_path)) == ".mcr" then
        (
            local file_dialog = dotNetObject "System.Windows.Forms.OpenFileDialog"
            file_dialog.Title = "Relocate missing MacroScript file"
            file_dialog.Filter = "Macroscripts (*.mcr)|*.mcr|All files (*.*)|*.*"
            file_dialog.CheckFileExists = true
            file_dialog.RestoreDirectory = true
            file_dialog.InitialDirectory = initial_dir
            file_dialog.FileName = path_class.GetFileName old_path
            try
            (
                if (file_dialog.ShowDialog()) == dialog_result.OK then
                    replacement_path = file_dialog.FileName as string
            )
            catch
            (
                format "Menu Manager: failed to browse missing MacroScript file %: %\n" old_path (getCurrentException())
            )
            file_dialog.Dispose()
        )
        else
        (
            local folder_dialog = dotNetObject "System.Windows.Forms.FolderBrowserDialog"
            folder_dialog.Description = "Relocate missing MacroScript directory: " + old_path
            folder_dialog.ShowNewFolderButton = false
            folder_dialog.SelectedPath = if doesDirectoryExist old_path then old_path else initial_dir
            try
            (
                if (folder_dialog.ShowDialog()) == dialog_result.OK then
                    replacement_path = folder_dialog.SelectedPath as string
            )
            catch
            (
                format "Menu Manager: failed to browse missing MacroScript folder %: %\n" old_path (getCurrentException())
            )
            folder_dialog.Dispose()
        )
        replacement_path -- return
    )

    /* Relocate only a missing MacroScript source and save the updated path.
       Keep original list ordering, preview selection, and all other INI entries.
    */
    function relocateMissingMacroSource =
    (
        local selected_index = getSelectedMacroSourceIndex()
        if selected_index < 0 or selected_index >= draft_macro_sources.count then return false

        local old_path = draft_macro_sources[selected_index + 1]
        if doesFileExist old_path or doesDirectoryExist old_path then return false

        local new_path = browseMissingMacroSource old_path
        if new_path == undefined or new_path == "" then return false
        if not (doesFileExist new_path or doesDirectoryExist new_path) then return false

        local duplicate_index = findItem draft_macro_sources new_path
        if duplicate_index > 0 and duplicate_index != selected_index + 1 then
        (
            format "Menu Manager: replacement MacroScript source already exists in list: %\n" new_path
            return false
        )

        draft_macro_sources[selected_index + 1] = new_path
        source_lists_dirty = true
        refreshSourceLists selected_macro_path:new_path
        saveDraftSources()
        format "Menu Manager: relocated MacroScript source: % -> %\n" old_path new_path
        true -- return
    )

    /* Parse .mcr files of the selected path without registering actions.
       Do not modify MENU_MANAGER_GLOBAL until SAVE & APPLY or INSTALL.
    */
    function refreshMacroPreview =
    (
        if macro_selection_refresh_suspended then return false

        macro_data = #()

        local selected_index = getSelectedMacroSourceIndex()
        if selected_index >= 0 and selected_index < draft_macro_sources.count then
        (
            local source_path = draft_macro_sources[selected_index + 1]
            try
            (
                local preview_manager = MenuManager_v()
                local macro_files = #()
                if doesDirectoryExist source_path then
                    macro_files = getFiles (pathConfig.appendPath source_path "*.mcr") recurse:true
                else if doesFileExist source_path then
                    append macro_files source_path
                local allowed_files = for macro_file in macro_files where not (preview_manager.Blacklist.isOnBlacklist macro_file blacklist:#MENUS) collect macro_file

                if allowed_files.count > 0 then
                (
                    local parsed_menus = ParsedMenusData_v(allowed_files)
                    for menu_name in parsed_menus.menus_data.keys do
                        appendIfUnique macro_data menu_name
                )
            )
            catch
            (
                format "Menu Manager: could not parse macroscripts at %: %\n" source_path (getCurrentException())
                lblIniInfo.text = "ERROR: cannot parse selected MacroScript source. See MAXScript Listener."
            )
        )

        MenuManagerUICallbacks.buildMacroTree macro_data MenuManagerMacros_ROLLOUT.tv_menus
        MenuManagerUICallbacks.groupMacroMenuTree MenuManagerMacros_ROLLOUT.tv_menus.Nodes
        refreshInstalledStates()
        MenuManagerMacros_ROLLOUT.lblMacroTree.text = "MACROSCRIPT MENUS (" + (macro_data.count as string) + ")"
        true -- return
    )

    /* Keep source selection stable when the configured lists change.
       Select the first source on opening a panel with saved paths.
    */
    function refreshSourceLists selected_macro_path:undefined selected_quad_path:undefined =
    (
        local macro_list = MenuManagerMacros_ROLLOUT.lstMacroSources
        local quad_list = MenuManagerQuads_ROLLOUT.lstQuadSources

        if selected_macro_path == undefined then
        (
            local previous_index = getSelectedMacroSourceIndex()
            if previous_index >= 0 and previous_index < draft_macro_sources.count then
                selected_macro_path = draft_macro_sources[previous_index + 1]
        )
        if selected_quad_path == undefined and quad_list.SelectedIndex >= 0 then
            selected_quad_path = quad_list.SelectedItem as string

        macro_selection_refresh_suspended = true
        macro_list.Items.Clear()
        quad_list.Items.Clear()

        local drawing_color = dotNetClass "System.Drawing.Color"
        for source_path in draft_macro_sources do
        (
            local source_item = macro_list.Items.Add (source_path as string)
            source_item.ToolTipText = source_path as string
            if not (doesFileExist source_path or doesDirectoryExist source_path) then
                source_item.ForeColor = drawing_color.FromArgb 255 70 70
        )
        for source_path in draft_quad_sources do quad_list.Items.Add (source_path as string)

        local macro_index = findItem draft_macro_sources selected_macro_path
        local quad_index = findItem draft_quad_sources selected_quad_path

        if macro_index == 0 and draft_macro_sources.count > 0 then macro_index = 1
        if quad_index == 0 and draft_quad_sources.count > 0 then quad_index = 1

        if macro_index > 0 then
        (
            macro_list.Items.Item[macro_index - 1].Selected = true
            macro_list.Items.Item[macro_index - 1].Focused = true
        )
        if quad_index > 0 then quad_list.SelectedIndex = quad_index - 1

        macro_selection_refresh_suspended = false
        updateTreeLayout()
        fitDialogToOpenRollout()
        refreshMacroPreview()
    )

    /* Persist both editable source lists immediately without rebuilding menus.
       Keep unsaved changes flagged when the INI write or readback fails.
    */
    function saveDraftSources =
    (
        MenuManagerSourceSettings.macro_sources = copy draft_macro_sources #noMap
        MenuManagerSourceSettings.quad_sources = copy draft_quad_sources #noMap

        local saved_ok = MenuManagerSourceSettings.saveSources()

        if saved_ok then
        (
            source_lists_dirty = false
            lblIniInfo.text = "Saved: " + MenuManagerSourceSettings.ini_file_path
        )
        else
        (
            source_lists_dirty = true
            lblIniInfo.text = "ERROR: source paths were not saved. See MAXScript Listener."
        )

        saved_ok -- return
    )

    /* Add a browsed source and persist the updated list immediately.
       Select the browsed source so its menus are parsed immediately.
    */
    function addDraftSource source_path source_type =
    (
        if source_path != undefined and source_path != "" then
        (
            if source_type == #macro then
            (
                appendIfUnique draft_macro_sources source_path
                refreshSourceLists selected_macro_path:source_path
            )
            else
            (
                appendIfUnique draft_quad_sources source_path
                refreshSourceLists selected_quad_path:source_path
            )
            source_lists_dirty = true
            saveDraftSources()
        )
    )

    /* Remove the selected source and immediately update the preview.
       A selected neighbor is retained when other paths remain.
    */
    function removeDraftSource source_type =
    (
        if source_type == #macro then
        (
            local selected_index = getSelectedMacroSourceIndex()
            if selected_index >= 0 then
            (
                deleteItem draft_macro_sources (selected_index + 1)
                refreshSourceLists()
                source_lists_dirty = true
                saveDraftSources()
            )
        )
        else
        (
            local selected_index = MenuManagerQuads_ROLLOUT.lstQuadSources.SelectedIndex
            if selected_index >= 0 then
            (
                deleteItem draft_quad_sources (selected_index + 1)
                refreshSourceLists()
                source_lists_dirty = true
                saveDraftSources()
            )
        )
    )

    function updateQuadData =
    (
        quad_data = #()
        
        if MENU_MANAGER_GLOBAL != undefined then
        (
            if isProperty MENU_MANAGER_GLOBAL #quad_cfg_files then
            (
                for quad_cfg_path in MENU_MANAGER_GLOBAL.quad_cfg_files do
                    appendIfUnique quad_data quad_cfg_path
            )
        )
    )
    function increaseTreeFontByOnePixel tree_view =
    (
        local pixel_in_points = 0.75
        local font_size = tree_view.Font.SizeInPoints + pixel_in_points
        tree_view.Font = dotNetObject "System.Drawing.Font" tree_view.Font.FontFamily font_size tree_view.Font.Style
    )

    function countVisibleTreeNodes nodes =
    (
        local visible_count = 0

        if nodes.Count > 0 then
        (
            for node_index = 0 to nodes.Count - 1 do
            (
                local node = nodes.Item[node_index]
                visible_count += 1
                if node.IsExpanded then
                    visible_count += countVisibleTreeNodes node.Nodes
            )
        )

        visible_count -- return
    )

    /* Refresh both trees from the configured menu manager instance.
       Used by the Refresh button and after Settings are applied.
    */
    function refreshSources =
    (
        updateQuadData()
        refreshSourceLists()
        MenuManagerUICallbacks.buildMacroTree quad_data MenuManagerQuads_ROLLOUT.tv_quads
        refreshInstalledStates()
        updateTreeLayout()
        fitDialogToOpenRollout()
    )

    on MenuManagerUI_ROLLOUT open do
    (
        addSubRollout sr_menu_sections MenuManagerMacros_ROLLOUT rolledUp:false
        addSubRollout sr_menu_sections MenuManagerQuads_ROLLOUT rolledUp:true

        local macro_tree = MenuManagerMacros_ROLLOUT.tv_menus
        local quad_tree = MenuManagerQuads_ROLLOUT.tv_quads
        local macro_list = MenuManagerMacros_ROLLOUT.lstMacroSources
        local quad_list = MenuManagerQuads_ROLLOUT.lstQuadSources
        local menus_editor_button = MenuManagerMacros_ROLLOUT.btnMenusEditor
        local quads_editor_button = MenuManagerQuads_ROLLOUT.btnQuadsEditor
        local drawing_color = dotNetClass "System.Drawing.Color"
        local dark_background = drawing_color.FromArgb 45 45 45
        local light_text = drawing_color.FromArgb 220 220 220

        for tree_view in #(macro_tree, quad_tree) do
        (
            tree_view.CheckBoxes = true
            tree_view.Sorted = true
            tree_view.HideSelection = false
            tree_view.BackColor = dark_background
            tree_view.ForeColor = light_text
            tree_view.LineColor = drawing_color.FromArgb 150 150 150
            increaseTreeFontByOnePixel tree_view
        )

        macro_list.View = (dotNetClass "System.Windows.Forms.View").Details
        macro_list.HeaderStyle = (dotNetClass "System.Windows.Forms.ColumnHeaderStyle").None
        macro_list.FullRowSelect = true
        macro_list.MultiSelect = false
        macro_list.HideSelection = false
        macro_list.ShowItemToolTips = true
        macro_list.Scrollable = true
        macro_list.BackColor = dark_background
        macro_list.ForeColor = light_text
        macro_list.Columns.Clear()
        macro_list.Columns.Add "MacroScript source" 508

        quad_list.HorizontalScrollbar = true
        quad_list.BackColor = dark_background
        quad_list.ForeColor = light_text

        ToolTitleButton.setupToolTitleButton btn_tool_title "MENU MANAGER UI"
        ToolTitleButton.resizeToolTitleButton btn_tool_title 552

        /* Apply the standard dark .NET button style to both editor launchers.
           Only their location changes; the forked menu-editor function is reused.
        */
        for editor_button in #(menus_editor_button, quads_editor_button) do
        (
            editor_button.UseVisualStyleBackColor = false
            editor_button.FlatStyle = (dotNetClass "System.Windows.Forms.FlatStyle").Flat
            editor_button.BackColor = drawing_color.FromArgb 68 68 68
            editor_button.ForeColor = drawing_color.FromArgb 190 190 190
            editor_button.FlatAppearance.BorderColor = drawing_color.FromArgb 120 120 120
            editor_button.FlatAppearance.BorderSize = 1
            editor_button.FlatAppearance.MouseOverBackColor = drawing_color.FromArgb 78 78 78
            editor_button.FlatAppearance.MouseDownBackColor = drawing_color.FromArgb 55 55 55
            editor_button.Font = dotNetObject "System.Drawing.Font" "Segoe UI" 9.0 (dotNetClass "System.Drawing.FontStyle").Bold
        )
        menus_editor_button.ForeColor = drawing_color.FromArgb 65 220 110
        quads_editor_button.ForeColor = drawing_color.FromArgb 62 158 255
        menus_editor_button.Text = "MENUS EDITOR"
        quads_editor_button.Text = "QUADS EDITOR"

        /* copy #noMap returns the array, unlike mapped copy (returns OK). */
        MenuManagerSourceSettings.loadSources()
        draft_macro_sources = copy MenuManagerSourceSettings.macro_sources #noMap
        draft_quad_sources = copy MenuManagerSourceSettings.quad_sources #noMap
        source_lists_dirty = false
        refreshSourceLists()
        lblIniInfo.text = "INI: " + MenuManagerSourceSettings.ini_file_path
        updateQuadData()
        MenuManagerUICallbacks.buildMacroTree quad_data quad_tree
		refreshInstalledStates()
		updateTreeLayout()
        auto_fit_ready = true
        fitDialogToOpenRollout()
    )

    on MenuManagerUI_ROLLOUT moved dialog_pos do
    (
        DialogHost.saveDialogPosition MenuManagerUI_ROLLOUT MenuManagerSourceSettings.ini_file_path "MenuManagerUI"
    )

    on MenuManagerUI_ROLLOUT resized dialog_size do
    (
        ToolTitleButton.resizeToolTitleButton btn_tool_title (dialog_size.x - 24)
        updateTreeLayout()
        DialogHost.saveDialogHeight MenuManagerUI_ROLLOUT MenuManagerSourceSettings.ini_file_path "MenuManagerUI" min_height:320
    )

    on MenuManagerUI_ROLLOUT close do
    (
        auto_fit_ready = false
        if source_lists_dirty then saveDraftSources()
        DialogHost.saveDialogState MenuManagerUI_ROLLOUT MenuManagerSourceSettings.ini_file_path "MenuManagerUI" min_height:320
    )

    on btn_tool_title Click sender event_args do
    (
        if MenuManagerUILauncherPath != undefined and doesFileExist MenuManagerUILauncherPath then
        (
            if source_lists_dirty == false or saveDraftSources() then
            (
                DialogHost.saveDialogState MenuManagerUI_ROLLOUT MenuManagerSourceSettings.ini_file_path "MenuManagerUI" min_height:320
                restartTool MenuManagerUILauncherPath (getFilenameFile MenuManagerUILauncherPath)
            )
        )
        else
        (
            format "Menu Manager: cannot restart; launcher file is missing: %\n" MenuManagerUILauncherPath
        )
    )

    on btnSaveSources pressed do
    (
        try
        (
            if saveDraftSources() then
            (
                MenuManagerSourceSettings.applySources()
                refreshSources()
                lblIniInfo.text = "Saved: " + MenuManagerSourceSettings.ini_file_path
            )
            else
            (
                messageBox ("Source settings could not be saved to:\n" + MenuManagerSourceSettings.ini_file_path + "\n\nSee MAXScript Listener.") title:"Menu Manager"
            )
        )
        catch
        (
            format "Menu Manager source settings failed: %\n" (getCurrentException())
            messageBox "Failed to save or apply source settings. See MAXScript Listener." title:"Menu Manager"
        )
    )

    on btnRefresh pressed do
    (
        refreshSources()
    )

)


/*
createDialog MenuManagerUI_ROLLOUT 724 540

*/

