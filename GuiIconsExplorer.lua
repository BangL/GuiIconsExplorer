require("lib/managers/menu/raid_menu/raidguibase")
require("lib/managers/menu/raid_menu/controls/raidguicontrol")

--------------------------------------------------------------------------------

---@class GuiIconsExplorer
---@field new fun(self, ws, fullscreen_ws, node):GuiIconsExplorer
---@field super table
---@field _node table
---@field _root_panel table
GuiIconsExplorer = GuiIconsExplorer or class(RaidGuiBase)

local padding = 10

function GuiIconsExplorer:init(ws, fullscreen_ws, node)
    GuiIconsExplorer.super.init(self, ws, fullscreen_ws, node, "gui_icons_explorer")
    self._root_panel.ctrls = self._root_panel.ctrls or {}
end

function GuiIconsExplorer:_set_initial_data()
    self._node.components.raid_menu_header:set_screen_name("raid_gui_icons_explorer")
end

function GuiIconsExplorer:_layout()
    self._object = self._root_panel:panel({})

    local header_height = self._node.components.raid_menu_header._screen_subtitle_label:bottom()
    local footer_height = self._node.components.raid_menu_footer._panel_h

    self._scroll = self._object:scrollable_area({
        name = "gui_icons_explorer_scroll",
        scroll_step = 35,
        x = padding,
        y = header_height + padding,
        w = self._object:w() - padding * 2,
        h = self._object:h() - header_height - footer_height - padding * 2,
    })
    local items_size = 420
    self._grid = self._scroll:get_panel():grid({
        name = "gui_icons_explorer_grid",
        scrollable_area_ref = self._scroll,
        w = self._scroll:w(),
        grid_params = {
            data_source_callback = callback(self, self, "_data_source"),
            on_click_callback = callback(self, self, "_on_icon_clicked"),
            scroll_marker_w = 32,
            vertical_spacing = 5,
        },
        item_params = {
            row_class = GuiIconsExplorerItem,
            key_value_field = "icon_id",
            grid_item_icon = "icon_id",
            item_h = items_size,
            item_w = items_size,
            selected_marker_h = items_size,
            selected_marker_w = items_size,
        },
    })

    -- hack to proxy grid:confirm_pressed to on_click_callback with selected item
    -- for some reason vanilla grids just have an empty confirm_pressed func as of now
    self._grid.confirm_pressed = function(grid)
        if grid._on_click_callback and grid._selected_item and grid._selected_item:get_data() then
            grid._on_click_callback(grid._selected_item:get_data())
        end
    end

    self._scroll:setup_scroll_area()
    self._grid:set_selected(true)
end

function GuiIconsExplorer:_additional_active_controls()
    return {
        self._grid
    }
end

function GuiIconsExplorer:_data_source()
    local icons = {}
    for icon_id, icon in pairs(tweak_data.gui.icons) do
        table.insert(icons, {
            icon_id = icon_id,
            texture = icon.texture,
            texture_rect = icon.texture_rect,
        })
    end
    table.sort(icons, function(l, r)
        return l.icon_id < r.icon_id
    end)
    return icons
end

function GuiIconsExplorer:_on_icon_clicked(selected_item_data)
    local msg = selected_item_data.icon_id
    if selected_item_data.texture_rect then
        msg = msg ..
            " (" ..
            tostring(selected_item_data.texture_rect[3]) ..
            "x" ..
            tostring(selected_item_data.texture_rect[4]) ..
            ")"
    end
    log(msg)
end

function GuiIconsExplorer:close()
    self._root_panel:clear()
    self._root_panel.ctrls = {}
end

--------------------------------------------------------------------------------

---@class GuiIconsExplorerItem
---@field new fun(self, parent, params, item_data, grid_params):GuiIconsExplorerItem
---@field super table
---@field _panel table
---@field _params table
---@field _object table
---@field _item_data table
GuiIconsExplorerItem = GuiIconsExplorerItem or class(RaidGUIControl)
GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE = 30
GuiIconsExplorerItem.LAYER_TRIANGLE = 15
GuiIconsExplorerItem.OUTLINE_THICKNESS = 1
GuiIconsExplorerItem.OUTLINE_THICKNESS_SELECTED = 3

function GuiIconsExplorerItem:init(parent, params, item_data, grid_params)
    GuiIconsExplorerItem.super.init(self, parent, params)

    self._item_data = item_data
    self._object = self._panel:panel({
        h = params.selected_marker_h,
        layer = 0,
        name = "panel_grid_item",
        w = params.selected_marker_w,
        x = params.x,
        y = params.y,
    }, true)
    self._selected = false

    if self._params and self._params.item_clicked_callback then
        self._on_click_callback = self._params.item_clicked_callback
    end

    if self._params and self._params.item_double_clicked_callback then
        self._on_double_click_callback = self._params.item_double_clicked_callback
    end

    if self._params and self._params.item_selected_callback then
        self._on_selected_callback = self._params.item_selected_callback
    end

    self._params.selected_marker_w = params.selected_marker_w or params.item_w or self._object:w()
    self._params.selected_marker_h = params.selected_marker_h or params.item_h or self._object:h()
    self._params.item_w = params.item_w or self._object:w()
    self._params.item_h = params.item_h or self._object:h()
    self._name = "grid_item"

    self:_layout_background()
    self:_layout_triangles()
    self:_layout_grid_item_content(params)
end

function GuiIconsExplorerItem:_layout_background()
    local image_coord_x = (self._params.selected_marker_w - self._params.item_w) / 2
    local image_coord_y = (self._params.selected_marker_h - self._params.item_h) / 2
    local grid_item_fg = tweak_data.gui:get_full_gui_data("grid_item_fg")
    self._grid_item_icon_fg = self._object:bitmap({
        color = tweak_data.gui.colors.grid_item_grey,
        h = self._params.item_h - GuiIconsExplorerItem.OUTLINE_THICKNESS * 2,
        layer = -1,
        name = "grid_item_icon_fg",
        texture = grid_item_fg.texture,
        texture_rect = grid_item_fg.texture_rect,
        w = self._params.item_w - GuiIconsExplorerItem.OUTLINE_THICKNESS * 2,
        x = image_coord_x + GuiIconsExplorerItem.OUTLINE_THICKNESS,
        y = image_coord_y + GuiIconsExplorerItem.OUTLINE_THICKNESS,
    })
end

function GuiIconsExplorerItem:_layout_triangles()
    self._triangle_markers_panel = self._object:panel({
        h = self._params.selected_marker_h,
        layer = 1,
        visible = false,
        w = self._params.selected_marker_w,
        x = 0,
        y = 0,
    })
    self._top_marker_triangle = self._triangle_markers_panel:image({
        color = tweak_data.gui.colors.raid_red,
        h = GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE,
        layer = GuiIconsExplorerItem.LAYER_TRIANGLE,
        texture = tweak_data.gui.icons.ico_sel_rect_top_left_white.texture,
        texture_rect = tweak_data.gui.icons.ico_sel_rect_top_left_white.texture_rect,
        w = GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE,
        x = 0,
        y = 0,
    })
    self._bottom_marker_triangle = self._triangle_markers_panel:image({
        color = tweak_data.gui.colors.raid_red,
        h = GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE,
        layer = 2,
        texture = tweak_data.gui.icons.ico_sel_rect_bottom_right_white.texture,
        texture_rect = tweak_data.gui.icons.ico_sel_rect_bottom_right_white.texture_rect,
        w = GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE,
        x = self._triangle_markers_panel:w() - GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE,
        y = self._triangle_markers_panel:h() - GuiIconsExplorerItem.SELECT_TRIANGLE_SIZE,
    })
end

function GuiIconsExplorerItem:_layout_grid_item_content(params)
    local icon_tweak = tweak_data.gui.icons[self._item_data[params.grid_item_icon]]

    -- Icon id
    local icon_id_text = self._object:label({
        name = "icon_id_text",
        font_size = BLT.fonts.medium.font_size,
        font = BLT.fonts.medium.font,
        layer = 12,
        color = tweak_data.gui.colors.raid_white,
        text = self._item_data.icon_id,
        fit_text = true,
    })
    icon_id_text:set_x(padding)
    local text_w = params.item_w - (padding * 2)
    icon_id_text:set_w(text_w)
    local _, _, tw = icon_id_text:text_rect()
    -- fit text
    if text_w < tw then
        local scale = text_w / tw
        icon_id_text:set_font_size(BLT.fonts.medium.font_size * scale)
    end
    -- bottom align icon_id text
    icon_id_text:set_bottom(self._object:h())

    -- Icon size text
    local unscaled_size = "unknown, no rect"
    if icon_tweak.texture_rect then
        unscaled_size = icon_tweak.texture_rect[3] .. " x " .. icon_tweak.texture_rect[4]
    end

    local icon_size_text = self._object:label({
        name = "icon_size_text",
        font_size = BLT.fonts.medium.font_size,
        font = BLT.fonts.medium.font,
        layer = 12,
        color = tweak_data.gui.colors.raid_white,
        text = "Unscaled size: " .. unscaled_size,
        fit_text = true,
    })
    icon_size_text:set_x(padding)
    icon_size_text:set_bottom(icon_id_text:top())

    -- Icon
    local icon_max_h = icon_size_text:top()
    self._grid_item_icon = self._object:bitmap({
        alpha = 1,
        layer = 15,
        name = "image",
        texture = icon_tweak.texture,
        texture_rect = icon_tweak.texture_rect,
    })
    while self._grid_item_icon:w() > params.item_w do
        self._grid_item_icon:set_w(self._grid_item_icon:w() - 1)
    end
    if icon_tweak.texture_rect then
        self._grid_item_icon:set_h(icon_tweak.texture_rect[4] * self._grid_item_icon:w() / icon_tweak.texture_rect[3])
    else
        self._grid_item_icon:set_h(self._grid_item_icon:w())
    end
    local resize_w_again = false
    while self._grid_item_icon:h() > icon_max_h do
        self._grid_item_icon:set_h(self._grid_item_icon:h() - 1)
        resize_w_again = true
    end
    if resize_w_again then
        if icon_tweak.texture_rect then
            self._grid_item_icon:set_w(icon_tweak.texture_rect[3] * self._grid_item_icon:h() / icon_tweak.texture_rect
                [4])
        else
            self._grid_item_icon:set_w(self._grid_item_icon:h())
        end
    end
    self._grid_item_icon:set_x((self._object:w() - self._grid_item_icon:w()) * 0.5)
    self._grid_item_icon:set_y((icon_max_h - self._grid_item_icon:h()) * 0.5)
end

function GuiIconsExplorerItem:get_data()
    return self._item_data
end

function GuiIconsExplorerItem:mouse_released(o, button, x, y)
    self:on_mouse_released(button)

    return true
end

function GuiIconsExplorerItem:on_mouse_released(button)
    if self._on_click_callback then
        self._on_click_callback(self._item_data, self._params.key_value_field)
    end
end

function GuiIconsExplorerItem:mouse_double_click(o, button, x, y)
    self:on_mouse_double_click(button)

    return true
end

function GuiIconsExplorerItem:on_mouse_double_click(button)
    if self._on_double_click_callback then
        self._on_double_click_callback(self._item_data, self._params.key_value_field)
    end
end

function GuiIconsExplorerItem:selected()
    return self._selected
end

function GuiIconsExplorerItem:select(dont_fire_selected_callback)
    self._selected = true

    self:select_on()

    if self._on_selected_callback and not dont_fire_selected_callback then
        self._on_selected_callback(self._params.item_idx, self._item_data)
    end
end

function GuiIconsExplorerItem:unselect()
    self._selected = false

    self:select_off()
end

function GuiIconsExplorerItem:select_on()
    self._triangle_markers_panel:show()
end

function GuiIconsExplorerItem:select_off()
    self._triangle_markers_panel:hide()
end

function GuiIconsExplorerItem:confirm_pressed()
    self:on_mouse_released(nil)
end

function GuiIconsExplorerItem:on_mouse_over(x, y)
    GuiIconsExplorerItem.super.on_mouse_over(self, x, y)

    if self._params.hover_selects and self._on_click_callback then
        self._on_click_callback(self._item_data, self._params.key_value_field)
    end
end

--------------------------------------------------------------------------------

Hooks:Add("MenuComponentManagerInitialize", "MenuComponentManagerInitialize.GuiIconsExplorer",
    function(self)
        RaidMenuHelper:CreateMenu({
            name = "raid_gui_icons_explorer",
            name_id = "raid_gui_icons_explorer",
            inject_list = "blt_options",
            icon = "menu_item_cards",
            class = GuiIconsExplorer,
        })
    end
)
