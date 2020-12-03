--- Arcify class.
-- Create a new instance to support Arc devices
--
-- @classmod Arcify
-- @release v1.0.0
-- @author Mimetaur (https://github.com/mimetaur)

local Arcify = {}
Arcify.__index = Arcify

-- constants
local LO_LED = 1
local HI_LED = 64
local MIN_INTENSITY = 0
local MAX_INTENSITY = 15
local DEFAULT_INTENSITY = 12
local NO_ASSIGMENT = "none"
local VALID_ORIENTATIONS = {0, 180}
local INTEGER_SCALE_FACTOR = 0.000001
local DEFAULT_SCALE = 0.001
local SHIFT_KEYS = {"none", "key 2", "key 3"}
local SHIFT_MODE = {"toggle", "hold"}

-- utility functions
local function round_delta(delta)
    if delta > 0 then
        return math.ceil(delta)
    else
        return math.floor(delta)
    end
end

local function scale_delta(delta, scale)
    return delta * scale
end

local function default_encoder_state()
    return {false, false, false, false}
end

local function param_info(name)
    local p = nil
    local id = params.lookup[name]
    p = params.params[id]
    return p
end

local function build_option_param(p)
    local newp = {}

    newp.friendly_name = p.name
    newp.name = p.id
    newp.min = 1
    newp.max = p.count
    newp.scale = (1 / p.count) * INTEGER_SCALE_FACTOR
    newp.is_rounded = true

    return newp
end

local function build_number_param(p, scale, is_rounded)
    local newp = {}

    newp.friendly_name = p.name
    newp.name = p.id
    newp.min = p.min
    newp.max = p.max
    newp.is_rounded = is_rounded or false
    if is_rounded then
        if not scale then
            scale = (1 / (max - min)) * INTEGER_SCALE_FACTOR
        end
    end
    newp.scale = scale or DEFAULT_SCALE

    return newp
end

local function build_taper_param(p, scale, is_rounded)
    local newp = {}

    newp.friendly_name = p.name
    newp.name = p.id
    newp.min = p.min
    newp.max = p.max
    newp.is_rounded = is_rounded or false
    if is_rounded then
        if not scale then
            scale = (1 / (max - min)) * INTEGER_SCALE_FACTOR
        end
    end
    newp.scale = scale or DEFAULT_SCALE

    return newp
end

local function build_control_param(p, scale, is_rounded)
    local cs = p.controlspec

    local newp = {}

    newp.friendly_name = p.name
    newp.name = p.id
    newp.min = cs.minval
    newp.max = cs.maxval
    newp.scale = scale or DEFAULT_SCALE
    newp.is_rounded = is_rounded

    return newp
end

-- private methods
local function draw_leds(self, num, amount, intensity)
    for i = LO_LED, amount do
        self.a_:led(num, i, intensity)
    end
end

local function redraw_ring(self, num, e)
    if e then
        if e.name and e.min and e.max then
            local param_led = math.ceil(util.linlin(e.min, e.max, LO_LED, HI_LED, params:get(e.name)))
            local intensity = e.intensity or DEFAULT_INTENSITY
            draw_leds(self, num, param_led, intensity)
        end
    end
end

local function redraw_all(self)
    local enc = self.encoders_

    if self.is_shifted_ then
        enc = self.shift_encoders_
    end

    self.a_:all(0)
    for num, name in ipairs(enc) do
        local param = self.params_[name]
        if param then
            redraw_ring(self, num, param)
        end
    end
    self.a_:refresh()
end

--- Params as options.
-- Builds an array of registered params starting with "none"
local function params_as_options(self)
    local param_names = {}
    table.insert(param_names, NO_ASSIGMENT)

    -- local sorted_params = tab.sort(self.params_)
    for idx, key_name in pairs(self.params_) do
        table.insert(param_names, key_name)
    end

    return param_names
end

local function build_encoder_mapping_param(self, encoder_num, is_shift)
    local opts = params_as_options(self)

    local offset = 0
    if is_shift then
        offset = 4
    end

    local param_id = "arc_encoder" .. encoder_num + offset .. "_mapping"
    local name = "Arc #" .. encoder_num
    if is_shift then
        name = "[shift] Arc #" .. encoder_num
    end

    params:add {
        type = "option",
        id = param_id,
        name = name,
        options = opts,
        default = 1,
        action = function(value)
            local opt_name = opts[value]
            if self.params_[opt_name] then
                self:map_encoder(encoder_num, opt_name, is_shift)
            elseif opt_name == NO_ASSIGMENT then
                self:clear_encoder_mapping(encoder_num, is_shift)
            end
        end
    }
end

--- Create a new Arcify object.
-- @param arc_obj Arc object (optional, creates its own)
-- @bool update_self By default, update its rings itself. False to update manually. (optional)
-- @int update_rate By default, 25 fps (optional)
-- @treturn Arcify Instance of Arcify.
function Arcify.new(arc_obj, update_self, update_rate)
    local ap = {}
    ap.a_ = arc_obj or arc.connect()
    ap.params_ = {}
    ap.encoders_ = default_encoder_state()
    ap.shift_encoders_ = default_encoder_state()
    ap.is_shifted_ = false
    ap.update_self_ = do_update_self or true -- create a callback by default
    ap.update_rate_ = update_rate or 1 / 25 -- 25 fps default

    if ap.update_self_ then
        local function redraw_callback()
            redraw_all(ap)
        end

        ap.on_redraw_ = metro.init(redraw_callback, ap.update_rate_, -1)
        ap.on_redraw_:start()
    end

    function ap.a_.delta(n, delta)
      -- TODO: how to filter here?
      -- if params:get("clock_source") == 1 then
      --   params:delta("clock_tempo", delta)
      -- end
        ap:update(n, delta)
    end

    setmetatable(ap, Arcify)
    return ap
end

--- Add Arcify assignment params to the Norns PARAMS screen.
function Arcify:add_params(allow_shift)
    -- TODO: check if separators count for the group count (otherwise, 12 -> 10)
    params:add_group("Arc mapping", allow_shift and 12 or 4)
    for i = 1, 4 do
        build_encoder_mapping_param(self, i, false)
    end

    if allow_shift then
        params:add_separator()
        params:add {
            type = "option",
            id = "arc_shift_key",
            name = "shift key",
            options = SHIFT_KEYS,
            default = 1
        }
        params:add {
            type = "option",
            id = "arc_shift_mode",
            name = "shift mode",
            options = SHIFT_MODE,
            default = 1
        }

        params:add_separator()
        for i = 1, 4 do
            build_encoder_mapping_param(self, i, true)
        end
    end
end

--- Register a param to be available to Arcify.
-- @string name_ ID of param
-- @number scale_ Multiplier to manage Arc sensitivity (optional)
-- @bool is_rounded_ Get rid of floating point values (optional)
function Arcify:register(name_, scale_, is_rounded_)
    if not name_ then
        print("Param is missing a name. Not registered.")
        return
    end
    -- from https://github.com/monome/norns/blob/dev/lua/core/paramset.lua
    -- TODO is there a way to introspect this from Norns code?
    -- or is it worth filing a PR to expose this from their code?

    -- currently valid types are:
    -- tNUMBER, tOPTION, tCONTROL
    local types = {
        tSEPARATOR = 0,
        tNUMBER = 1,
        tOPTION = 2,
        tCONTROL = 3,
        tFILE = 4,
        tTAPER = 5,
        tTRIGGER = 6
    }

    local p = param_info(name_)
    if not p then
        print("Referencing invalid param. Not registered.")
        return
    end

    local np = {}

    if p.t == types.tNUMBER then
        self.params_[name_] = build_number_param(p, scale_, is_rounded_)
    elseif p.t == types.tOPTION then
        self.params_[name_] = build_option_param(p)
    elseif p.t == types.tCONTROL then
        self.params_[name_] = build_control_param(p, scale_, is_rounded_)
    elseif p.t == types.tTAPER then
        self.params_[name_] = build_taper_param(p, scale_, is_rounded_)
    else
        print("Referencing invalid param. May be an unsupported type. Not registered.")
        return
    end
    return true
end

--- Map an encoder to a param.
-- @int position which encoder to map
-- @string param_name which param ID to map it to
-- @bool is_shift if mapping an encoder in shift mode
function Arcify:map_encoder(position, param_name, is_shift)
    if param_name == "none" then
        return
    elseif position < 1 or position > 4 then
        print("Invalid arc encoder number: " .. position)
        return
    elseif not self.params_[param_name] then
        print("Invalid parameter name: " .. param_name .. "at" .. position)
        return
    end
    if is_shift then
        self.shift_encoders_[position] = param_name
    else
        self.encoders_[position] = param_name
    end
end

--- Clear an encoder mapping.
-- @int position which encoder to clear
-- @bool is_shift if mapping an encoder in shift mode
function Arcify:clear_encoder_mapping(position, is_shift)
    if position < 1 or position > 4 then
        print("Invalid arc encoder number: " .. position)
        return
    end
    if is_shift then
        self.shift_encoders_[position] = false
    else
        self.encoders_[position] = false
    end
end
--- Clear all encoder mappings
function Arcify:clear_all_encoder_mappings()
    self.encoders_ = default_encoder_state()
end

--- Callback when an encoder is updated.
-- @int num which arc encoder is updated
-- @number delta how much it is updated
function Arcify:update(num, delta)
    local encoder_mapping = self.encoders_[num]

    if self.is_shifted_ then
        encoder_mapping = self.shift_encoders_[num]
    end

    local param = self.params_[encoder_mapping]
    if encoder_mapping and param then
        local new_delta = scale_delta(delta, param.scale)
        if param.is_rounded then
            new_delta = round_delta(new_delta)
        end
        local value = params:get(param.name) + new_delta
        params:set(param.name, value)
    end
end

--- Get the param ID value for a particular encoder.
-- @int enc_num which arc encoder to get Param ID for
function Arcify:param_id_at_encoder(enc_num)
    return self.encoders_[enc_num]
end

--- Get the param Name value for a particular encoder.
-- @int enc_num which arc encoder to get Param Name for
function Arcify:param_name_at_encoder(enc_num)
    local id = self.encoders_[enc_num]
    if id then
        return self.params_[id].friendly_name
    end
end

--- Redraw Arc rings.
-- You can call this manually instead of letting
-- Arcify refresh itself.
function Arcify:redraw()
    redraw_all(self)
end

--- Call this from inside the key() function
-- @int key_pressed is which key was pressed
-- @int key_state is whether it is up or down
function Arcify:handle_shift(key_pressed, key_state)
    local key_num = params:get("arc_shift_key")
    local key_mode = SHIFT_MODE[params:get("arc_shift_mode")]

    if not key_num or key_num == 1 then
        return
    end

    if key_num == key_pressed then
        if key_mode == "toggle" and key_state == 1 then
            self.is_shifted_ = not self.is_shifted_
        end

        if key_mode == "hold" and key_state == 1 then
            self.is_shifted_ = true
        end

        if key_mode == "hold" and key_state == 0 then
            self.is_shifted_ = false
        end
    end
end

return Arcify
