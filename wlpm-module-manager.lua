-- project: Warcraft 3 Lua Package Manager 1.1
-- author: ScorpioT1000 / scorpiot1000@yandex.ru / github.com/indaxia

local wlpmModules           = {}    ---@type WLPM[]     --used to immediately reference a module
local wlpmStack             = {}    ---@type string[]   --synchronous ordering of the modules when using "loadAll"
local _BACKWARDS_API_COMPAT = true  --1.1 consolidates API into a single global. Set to true if you don't need backwards-compat.
local _MAX_DEPTH            = 512

WLPM = {}
---@class WLPM
---@field loaded boolean
---@field dependencies table
---@field context function
---@field exports table
---@field exportDefault function

---The dependencies are optional, but the context is required.
---@param name string
---@param dependencies? table
---@param context fun(import : function, export : function, exportDefault : function)
function WLPM.declare(name, dependencies, context)
    if (type(dependencies) == "function") then
        context = dependencies
    elseif type(context) ~= "function" then
        print("WLPM Error: wrong module declaration: '" .. name .. "'. Module requires context function callback.")
        return
    end
    wlpmModules[name] = {
        loaded = false,
        dependencies = (type(dependencies) == "table" and dependencies) or {},
        context = context,
        exports = {},
        exportDefault = nil
    }
    wlpmStack[#wlpmStack+1] = name
end

---Load a declared module. The depth is only used internally and should be omitted from external API.
---@param name string
---@param depth? integer
---@return WLPM
function WLPM.load(name, depth)
    local theModule = wlpmModules[name] ---@type WLPM
    if (type(depth) == 'number') then
        if (depth > _MAX_DEPTH) then
            print("WLPM Error: dependency loop detected for the module '" .. name .. "'")
            return
        end
        depth = depth + 1
    elseif (type(theModule) ~= "table") then
        print("WLPM Error: module '" .. name .. "' not exists or not yet loaded. Call importWM at your initialization section")
        return
    else
        depth = 0
    end
    if (not theModule.loaded) then
        for _, dependency in ipairs(theModule.dependencies) do
            WLPM.load(dependency, depth)
        end
        
        ---import default or import special
        ---@param moduleOrWhatToImport string
        ---@param moduleToImport? string
        ---@return WLPM
        local cb_import = function(moduleOrWhatToImport, moduleToImport)
            if (type(moduleToImport) ~= "string") then
                return WLPM.import(moduleOrWhatToImport)
            end
            return WLPM.import(moduleToImport, moduleOrWhatToImport)
        end
        ---export object or key and value
        ---@param whatToExport table|string
        ---@param singleValue? any
        local cb_export = function(whatToExport, singleValue)
            if (type(whatToExport) == "table") then
                for k,v in pairs(whatToExport) do theModule.exports[k] = v end -- merges exports
            elseif (type(whatToExport) == "string") then
                theModule.exports[whatToExport] = singleValue
            else
                print("WLPM Error: wrong export syntax in module '" .. name .. "'. Use export() with a single object arg or key-value args")
                return
            end
        end
        ---@param defaultExport any
        local cb_exportDefault = function(defaultExport)
            if (defaultExport == nil) then
                print("WLPM Error: wrong default export syntax in module '" .. name .. "'. Use exportDefault() with an argument")
                return
            end
            theModule.exportDefault = defaultExport
        end
        
        theModule.context(cb_import, cb_export, cb_exportDefault)
        theModule.loaded = true
    end
    
    return theModule
end

---@param name string
---@param whatToImport? string
---@return any
function WLPM.import(name, whatToImport)
    local theModule = WLPM.load(name)
    if (type(whatToImport) == "string") then
        if(theModule.exports[whatToImport] == nil) then
            print("WLPM Error: name '" .. whatToImport .. "' was never exported by the module '" .. name .. "'")
            return
        end
        return theModule.exports[whatToImport]
    end
    return theModule.exportDefault
end

-- call to disable lazy loading mechanics
function WLPM.loadAll()
    for _,name in ipairs(wlpmStack) do
        WLPM.load(wlpmModules[name])
    end
end

--backwards-compatible API:
if _BACKWARDS_API_COMPAT then
    WM                  = WLPM.declare
    importWM            = WLPM.import
    loadAllWMs          = WLPM.loadAll
    wlpmDeclareModule   = WM
    wlpmImportModule    = importWM
    wlpmLoadAllModules  = loadAllWMs
end
