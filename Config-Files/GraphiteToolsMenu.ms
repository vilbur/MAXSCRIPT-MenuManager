/*
GraphiteToolsMenu.ms
File Version: 0.01
Project Version: 0.10

Builds an independent "Graphite tools" main menu with MenuBuilder.
The menu binds to the existing PolyTools Action Items used by the Graphite Ribbon.
*/

global GRAPHITE_TOOLS_MENU_PROJECT_VERSION
global GraphiteToolsMenu

struct GraphiteToolsMenu_v
(
    file_version = 0.01,
    project_version = 0.10,
    root_menu_title = "Graphite tools",
    action_category = "PolyTools",
    macro_action_table_id = 647394,
    bound_functions = #(),
    unresolved_functions = #(),
    ambiguous_functions = #(),
    last_json_path = "",

    /*
    Normalize text for tolerant Action Item matching.
    Removes punctuation and spacing while preserving letters and digits.
    */
    function normalizeText source_text =
    (
        normalized_text = ""
        if source_text != undefined then
        (
            normalized_text = toLower (source_text as string)
            for separator_text in #( " ", "_", "-", ".", "(", ")", "[", "]", "{", "}", "/", "\\", ":", ";", ",", "'", "\"", "+", "&" ) do
            (
                normalized_text = substituteString normalized_text separator_text ""
            )
        )
        normalized_text -- return
    ),

    /*
    Append a string only when it is not already present.
    Empty strings are ignored.
    */
    function appendUniqueString string_array string_value =
    (
        if string_value != undefined then
        (
            string_value = string_value as string
            if string_value != "" and (findItem string_array string_value) == 0 then append string_array string_value
        )
        string_array -- return
    ),

    /*
    Test whether normalized source text ends with normalized suffix text.
    Used to prefer method-name suffixes in PolyTools MacroScript command names.
    */
    function textEndsWith source_text suffix_text =
    (
        result_value = false
        if source_text != undefined and suffix_text != undefined then
        (
            if source_text.count >= suffix_text.count and suffix_text.count > 0 then
            (
                result_value = (substring source_text (source_text.count - suffix_text.count + 1) suffix_text.count) == suffix_text
            )
        )
        result_value -- return
    ),

    /*
    Read an Action Item persistent ID without depending on one API spelling.
    Returns an empty string when no persistent ID can be obtained.
    */
    function getPersistentActionId action_item =
    (
        persistent_id = ""
        try (persistent_id = action_item.persistentActionId as string) catch (persistent_id = "")
        persistent_id -- return
    ),

    /*
    Extract a MacroScript command name from a persistent MacroScript Action ID.
    Persistent MacroScript IDs use the form macroName`category.
    */
    function getMacroNameFromPersistentId persistent_id =
    (
        macro_name = persistent_id as string
        separator_index = findString macro_name "`"
        if separator_index != undefined then
        (
            macro_name = substring macro_name 1 (separator_index - 1)
        )
        macro_name -- return
    ),

    /*
    Read the Action Item category text.
    Uses the 3ds Max 2026 property first and the legacy getter as fallback.
    */
    function getActionCategory action_item =
    (
        category_text = ""
        try (category_text = action_item.category as string) catch
        (
            try (action_item.getCategory &category_text) catch (category_text = "")
        )
        category_text -- return
    ),

    /*
    Collect searchable text exposed by an Action Item.
    Includes persistent command name, menu text, button text, and description.
    */
    function getActionTexts action_item =
    (
        action_texts = #()
        persistent_id = this.getPersistentActionId action_item
        macro_name = this.getMacroNameFromPersistentId persistent_id
        menu_text = ""
        button_text = ""
        description_text = ""

        this.appendUniqueString action_texts macro_name
        this.appendUniqueString action_texts persistent_id

        try (menu_text = action_item.menuText as string) catch (try (action_item.getMenuText &menu_text) catch (menu_text = ""))
        try (button_text = action_item.buttonText as string) catch (try (action_item.getButtonText &button_text) catch (button_text = ""))
        try (description_text = action_item.description as string) catch (try (action_item.getDescription &description_text) catch (description_text = ""))

        this.appendUniqueString action_texts menu_text
        this.appendUniqueString action_texts button_text
        this.appendUniqueString action_texts description_text
        action_texts -- return
    ),

    /*
    Build candidate labels for one documented PolyTools interface method.
    Adds method, UI title, aliases, and likely interface-prefixed command names.
    */
    function getMethodCandidates interface_name method_name menu_title aliases:#() =
    (
        candidates = #()
        family_name = substituteString interface_name "PolyTools" ""

        this.appendUniqueString candidates method_name
        this.appendUniqueString candidates menu_title
        this.appendUniqueString candidates (family_name + " " + method_name)
        this.appendUniqueString candidates (family_name + " " + menu_title)
        this.appendUniqueString candidates ("PolyTools " + family_name + " " + method_name)
        this.appendUniqueString candidates ("PolyTools " + family_name + " " + menu_title)

        if interface_name == "PolyToolsSelect" then
        (
            this.appendUniqueString candidates ("Selection " + method_name)
            this.appendUniqueString candidates ("Selection " + menu_title)
            this.appendUniqueString candidates ("Select " + method_name)
            this.appendUniqueString candidates ("Select " + menu_title)
        )

        for alias_text in aliases do this.appendUniqueString candidates alias_text
        candidates -- return
    ),

    /*
    Score one PolyTools Action Item against one documented interface method.
    Exact method/title matches dominate; family-qualified and contained matches are fallbacks.
    */
    function scoreActionItem action_item action_table interface_name method_name menu_title aliases:#() =
    (
        score_value = 0
        category_text = this.getActionCategory action_item

        if (toLower category_text) == (toLower this.action_category) then
        (
            action_texts = this.getActionTexts action_item
            candidates = this.getMethodCandidates interface_name method_name menu_title aliases:aliases
            method_normalized = this.normalizeText method_name
            title_normalized = this.normalizeText menu_title
            family_normalized = this.normalizeText (substituteString interface_name "PolyTools" "")

            for action_text in action_texts do
            (
                action_normalized = this.normalizeText action_text

                if action_normalized == method_normalized and score_value < 140 then score_value = 140
                if action_normalized == title_normalized and score_value < 135 then score_value = 135

                for candidate_text in candidates do
                (
                    candidate_normalized = this.normalizeText candidate_text
                    if action_normalized == candidate_normalized and score_value < 130 then score_value = 130
                )

                if method_normalized.count >= 5 and (findString action_normalized method_normalized) != undefined then
                (
                    if score_value < 70 then score_value = 70
                )

                if method_normalized.count >= 4 and this.textEndsWith action_normalized method_normalized then
                (
                    if score_value < 90 then score_value = 90
                )

                if family_normalized != "" and (findString action_normalized family_normalized) != undefined and (findString action_normalized method_normalized) != undefined then
                (
                    if score_value < 110 then score_value = 110
                )
            )

            if score_value > 0 and action_table.id == this.macro_action_table_id then score_value += 5
        )

        score_value -- return
    ),

    /*
    Find the strongest unique PolyTools Action Item for one interface method.
    Returns #(actionItem, actionTable, score) or undefined when missing or tied.
    */
    function findBestAction interface_name method_name menu_title aliases:#() =
    (
        best_action = undefined
        best_table = undefined
        best_score = 0
        best_count = 0

        for table_index = 1 to actionMan.numActionTables do
        (
            action_table = actionMan.getActionTable table_index
            if action_table != undefined then
            (
                for action_index = 1 to action_table.numActionItems do
                (
                    action_item = action_table.getActionItem action_index
                    if action_item != undefined then
                    (
                        action_score = this.scoreActionItem action_item action_table interface_name method_name menu_title aliases:aliases

                        if action_score > best_score then
                        (
                            best_score = action_score
                            best_action = action_item
                            best_table = action_table
                            best_count = 1
                        )
                        else if action_score == best_score and action_score > 0 then
                        (
                            best_count += 1
                        )
                    )
                )
            )
        )

        if best_score <= 0 then
        (
            undefined
        )
        else if best_count != 1 then
        (
            append this.ambiguous_functions (interface_name + "." + method_name + " | score:" + (best_score as string) + " | matches:" + (best_count as string))
            undefined
        )
        else
        (
            #(best_action, best_table, best_score)
        ) -- return
    ),

    /*
    Append one exact native Action Item binding to a MenuBuilder menu definition.
    Saved actionTableID and persistentActionId keep the same command used by the Ribbon.
    */
    function appendBoundAction menu_definition interface_name method_name menu_title aliases:#() =
    (
        match_data = this.findBestAction interface_name method_name menu_title aliases:aliases
        action_added = false

        if match_data != undefined then
        (
            action_item = match_data[1]
            action_table = match_data[2]
            action_score = match_data[3]
            action_category_text = this.getActionCategory action_item
            persistent_id = this.getPersistentActionId action_item
            action_name = this.getMacroNameFromPersistentId persistent_id

            if action_name == "" then
            (
                action_texts = this.getActionTexts action_item
                if action_texts.count > 0 then action_name = action_texts[1]
            )

            item_data = menu_definition.makeMacroItemData menu_title action_category_text action_name custom_title:true
            item_data[#action_table_id] = action_table.id
            item_data[#persistent_action_id] = persistent_id
            menu_definition.appendSavedItem item_data

            append this.bound_functions (interface_name + "." + method_name + " -> " + persistent_id + " | score:" + (action_score as string))
            action_added = true
        )
        else
        (
            append this.unresolved_functions (interface_name + "." + method_name)
        )

        action_added -- return
    ),

    /*
    Add one logical group of interface methods as a submenu.
    Each specification is #(methodName, menuTitle, aliases).
    */
    function addMethodGroup parent_menu interface_name group_title method_specs =
    (
        group_menu = parent_menu.menu group_title
        group_menu.clearItems()

        for method_spec in method_specs do
        (
            method_name = method_spec[1]
            menu_title = method_spec[2]
            aliases = if method_spec.count >= 3 then method_spec[3] else #()
            this.appendBoundAction group_menu interface_name method_name menu_title aliases:aliases
        )

        group_menu -- return
    ),

    /*
    Return documented PolyToolsSelect methods organized like the Graphite selection UI.
    Aliases include common Ribbon labels for controls that represent multiple interface methods.
    */
    function getSelectGroups =
    (
        #(
            #( "Modify Selection", #(
                #( "Loop", "Loop", #( "Select Loop" ) ),
                #( "Ring", "Ring", #( "Select Ring" ) ),
                #( "GrowLoop", "Grow Loop", #() ),
                #( "ShrinkLoop", "Shrink Loop", #() ),
                #( "GrowRing", "Grow Ring", #() ),
                #( "ShrinkRing", "Shrink Ring", #() ),
                #( "DotLoop", "Dot Loop", #() ),
                #( "DotRing", "Dot Ring", #() ),
                #( "StepLoop", "Step Loop", #() ),
                #( "Outline", "Outline", #() ),
                #( "Fill", "Fill", #( "Fill Selection" ) ),
                #( "FillHole", "Fill Hole", #() ),
                #( "Similar", "Similar", #( "Select Similar" ) )
            ) ),
            #( "Select", #(
                #( "Tops", "Tops", #( "Select Tops", "Top" ) ),
                #( "HardEdges", "Hard Edges", #( "Select Hard Edges" ) )
            ) ),
            #( "By Random", #(
                #( "Random", "Random", #( "By Random", "Random Selection" ) ),
                #( "RandomGrow", "Random Grow", #( "Grow Random" ) ),
                #( "RandomShrink", "Random Shrink", #( "Shrink Random" ) ),
                #( "Even", "Even", #( "Select Even" ) ),
                #( "Odd", "Odd", #( "Select Odd" ) )
            ) ),
            #( "By Symmetry", #(
                #( "Symmetry", "Symmetry", #( "By Symmetry", "Select Symmetry" ) )
            ) ),
            #( "By Numeric", #(
                #( "NumericVertex", "Numeric Vertex", #( "By Numeric", "Numeric" ) ),
                #( "NumericEdge", "Numeric Edge", #( "By Numeric", "Numeric" ) ),
                #( "NumericFace", "Numeric Face", #( "By Numeric", "Numeric" ) )
            ) ),
            #( "By Half", #(
                #( "Half", "Half", #( "By Half", "Select Half" ) )
            ) ),
            #( "By Normal", #(
                #( "Normal", "Normal", #( "By Normal", "Select By Normal" ) )
            ) ),
            #( "By Perspective", #(
                #( "Perspective", "Perspective", #( "By Perspective", "Select By Perspective" ) ),
                #( "PerspectiveGrow", "Perspective Grow", #( "Grow From Perspective", "Perspective Grow" ) )
            ) ),
            #( "By Pivot Distance", #(
                #( "Distance", "Distance", #( "Pivot Distance", "By Pivot Distance" ) )
            ) ),
            #( "By Surface", #(
                #( "ConvexConcave", "Convex / Concave", #( "Convex Concave", "Concave Convex", "By Surface" ) )
            ) ),
            #( "Patterns", #(
                #( "Pattern1", "Pattern 1", #() ),
                #( "Pattern2", "Pattern 2", #() ),
                #( "Pattern3", "Pattern 3", #() ),
                #( "Pattern4", "Pattern 4", #() ),
                #( "Pattern5", "Pattern 5", #() ),
                #( "Pattern6", "Pattern 6", #() ),
                #( "Pattern7", "Pattern 7", #() ),
                #( "Pattern8", "Pattern 8", #() ),
                #( "PatternDots", "Pattern Dots", #( "Dots" ) ),
                #( "PatternChecker", "Pattern Checker", #( "Checker" ) ),
                #( "PatternGrowLine", "Pattern Grow Line", #( "Grow Line" ) ),
                #( "PatternOneRing", "Pattern One Ring", #( "One Ring" ) )
            ) ),
            #( "By Bitmap", #(
                #( "BitmapToSel", "Bitmap To Selection", #( "By Bitmap", "Bitmap" ) )
            ) )
        ) -- return
    ),

    /*
    Return documented PolyToolsModeling methods organized like Graphite modeling panels.
    Aliases include likely Ribbon command labels for context-sensitive controls.
    */
    function getModelingGroups =
    (
        #(
            #( "Loops", #(
                #( "DistanceConnect", "Distance Connect", #() ),
                #( "RemoveLoop", "Remove Loop", #() ),
                #( "SetFlow", "Set Flow", #() ),
                #( "SetFlowVertex", "Set Flow Vertex", #( "Set Flow" ) ),
                #( "BuildEnd", "Build End", #() ),
                #( "BuildCorner", "Build Corner", #() ),
                #( "RandomConnect", "Random Connect", #() )
            ) ),
            #( "Edges", #(
                #( "SpinEdge", "Spin Edge", #() ),
                #( "InsertVertex", "Insert Vertex", #( "Insert Vertices" ) )
            ) ),
            #( "Geometry - All", #(
                #( "Quadrify", "Quadrify", #() )
            ) ),
            #( "Polygons", #(
                #( "GeoPoly", "GeoPoly", #( "Geo Poly" ) )
            ) ),
            #( "Loop Tools", #(
                #( "CenterLoop", "Center Loop", #() ),
                #( "SpaceLoop", "Space Loop", #() ),
                #( "CurveLoop", "Curve Loop", #() ),
                #( "StraightLoop", "Straight Loop", #() ),
                #( "CircleLoop", "Circle Loop", #() ),
                #( "RelaxLoop", "Relax Loop", #() )
            ) ),
            #( "Symmetry", #(
                #( "SymmetryGather", "Symmetry Gather", #( "Gather Symmetry", "Symmetry Tools" ) ),
                #( "SymmetryPosToNeg", "Symmetry + To -", #( "+ To -", "+To-", "Positive To Negative", "Symmetry Tools" ) ),
                #( "SymmetryNegToPos", "Symmetry - To +", #( "- To +", "-To+", "Negative To Positive", "Symmetry Tools" ) ),
                #( "SymmetryFlip", "Symmetry Flip", #( "Flip Symmetry", "Symmetry Tools" ) ),
                #( "SymmetryCopy", "Symmetry Copy", #( "Copy Symmetry", "Symmetry Tools" ) ),
                #( "SymmetryPaste", "Symmetry Paste", #( "Paste Symmetry", "Symmetry Tools" ) )
            ) ),
            #( "Other", #(
                #( "MultiHide", "Multi Hide", #() ),
                #( "RotateSelection", "Rotate Selection", #() ),
                #( "MirrorElement", "Mirror Element", #() ),
                #( "CreateFace", "Create Face", #() )
            ) )
        ) -- return
    ),

    /*
    Return documented PolyToolsTopology methods.
    The API method is intentionally spelled Mosiac to match Autodesk's interface.
    */
    function getTopologyGroups =
    (
        #(
            #( "Topology", #(
                #( "Wall", "Wall", #() ),
                #( "Tiles1", "Tiles 1", #( "Tile 1" ) ),
                #( "Tiles2", "Tiles 2", #( "Tile 2" ) ),
                #( "Brick", "Brick", #() ),
                #( "Hive", "Hive", #() ),
                #( "Mosiac", "Mosaic", #( "Mosiac" ) ),
                #( "Floor1", "Floor 1", #() ),
                #( "Floor2", "Floor 2", #() ),
                #( "Skin", "Skin", #() ),
                #( "Holer", "Holer", #( "Holes", "Hole" ) ),
                #( "EdgeDirection", "Edge Direction", #() ),
                #( "Simplify", "Simplify", #() ),
                #( "Chaos", "Chaos", #() ),
                #( "Fours", "Fours", #() ),
                #( "SmoothStar", "Smooth Star", #() ),
                #( "Cross", "Cross", #() ),
                #( "Planks1", "Planks 1", #( "Plank 1" ) ),
                #( "Planks2", "Planks 2", #( "Plank 2" ) ),
                #( "Planks3", "Planks 3", #( "Plank 3" ) ),
                #( "Planks4", "Planks 4", #( "Plank 4" ) ),
                #( "Tatter", "Tatter", #() ),
                #( "ScrapVerts", "Scrap Verts", #( "Scrap Vertices" ) )
            ) )
        ) -- return
    ),

    /*
    Ensure the repository MenuBuilder include has been loaded.
    The Graphite producer remains independent from MenuBuilder implementation files.
    */
    function ensureMenuBuilder =
    (
        if MENU_MANAGER_GLOBAL == undefined then
        (
            source_directory = getFilenamePath (getSourceFileName())
            include_path = source_directory + "..\\include-MenuManager.ms"
            if doesFileExist include_path then filein include_path
        )

        (MENU_MANAGER_GLOBAL != undefined) -- return
    ),

    /*
    Build one PolyTools interface branch from grouped method specifications.
    Existing generated submenu content is cleared before regeneration.
    */
    function buildInterfaceMenu root_menu interface_name grouped_specs =
    (
        interface_menu = root_menu.menu interface_name
        interface_menu.clearItems()

        for group_spec in grouped_specs do
        (
            group_title = group_spec[1]
            method_specs = group_spec[2]
            this.addMethodGroup interface_menu interface_name group_title method_specs
        )

        interface_menu -- return
    ),

    /*
    Generate and install the independent Graphite tools main menu.
    MenuBuilder merges it with existing data and writes Graphite tools.json as a split menu file.
    */
    function buildMenu install:true =
    (
        build_ok = false
        this.bound_functions = #()
        this.unresolved_functions = #()
        this.ambiguous_functions = #()
        this.last_json_path = ""

        if this.ensureMenuBuilder() then
        (
            root_menu = MENU_MANAGER_GLOBAL.menu this.root_menu_title load_native_items:false
            if root_menu != undefined then
            (
                root_menu.clearItems()

                this.buildInterfaceMenu root_menu "PolyToolsSelect" (this.getSelectGroups())
                this.buildInterfaceMenu root_menu "PolyToolsModeling" (this.getModelingGroups())
                this.buildInterfaceMenu root_menu "PolyToolsTopology" (this.getTopologyGroups())

                if install then MENU_MANAGER_GLOBAL.createMenus which:#(this.root_menu_title)

                this.last_json_path = MENU_MANAGER_GLOBAL.MenuBuildManager.getSplitJsonFilePathByTitle this.root_menu_title menu_type:#menu
                build_ok = true
            )
        )

        this.printReport()
        build_ok -- return
    ),

    /*
    Print native Action Item binding results and the generated split JSON path.
    Unresolved or ambiguous methods remain visible for targeted adjustment on the installed Max version.
    */
    function printReport =
    (
        format "\n============================================================\n"
        format "GRAPHITE TOOLS MENU % | PROJECT %\n" this.file_version this.project_version
        format "Bound: %\n" this.bound_functions.count
        format "Unresolved: %\n" this.unresolved_functions.count
        format "Ambiguous: %\n" this.ambiguous_functions.count
        if this.last_json_path != "" then format "Config: %\n" this.last_json_path

        if this.unresolved_functions.count > 0 then
        (
            format "\nUNRESOLVED:\n"
            for function_name in this.unresolved_functions do format "  %\n" function_name
        )

        if this.ambiguous_functions.count > 0 then
        (
            format "\nAMBIGUOUS:\n"
            for function_name in this.ambiguous_functions do format "  %\n" function_name
        )

        format "============================================================\n\n"
        true -- return
    ),

    on create do
    (
        if GRAPHITE_TOOLS_MENU_PROJECT_VERSION == undefined then
        (
            GRAPHITE_TOOLS_MENU_PROJECT_VERSION = project_version
        )
        else if project_version > GRAPHITE_TOOLS_MENU_PROJECT_VERSION then
        (
            GRAPHITE_TOOLS_MENU_PROJECT_VERSION = project_version
        )
    )
)

GraphiteToolsMenu = GraphiteToolsMenu_v()
GraphiteToolsMenu.buildMenu()
