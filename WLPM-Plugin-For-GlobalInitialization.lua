-- project: Warcraft 3 Lua Package Manager
-- author: ScorpioT1000 / scorpiot1000@yandex.ru / github.com/indaxia
-- Re-tooled to work seamlessly with Total Initialization v5.
do
    local exportMap = {}

    ---Import a module. If it is not yet declared, yield the thread until it is. If a second parameter is specified,
    ---then the first parameter needs to be a specific component of that module. Compare to JavaScript's "import {useState} from 'react'".
    ---@param whichModule string
    ---@param actualModule? string
    function importWM(whichModule, actualModule)
        local result = Require(actualModule or whichModule)
        if actualModule and exportMap[actualModule] then
            return exportMap[actualModule][whichModule]
        end
        return result
    end
    ---Declare a module and a function to be called to initialize it.
    ---@param name string
    ---@param imports? table
    ---@param initFunc fun(import:importWM, export:fun(contents:table|string, value?:string), exportDefault:fun(value:any))
    function WM(name, imports, initFunc)
        local userFunc
        if initFunc then
            userFunc = initFunc
            imports = imports or {}
        else
            userFunc,imports = imports,{}
        end
        if type(userFunc)~="function" then
            error("Invalid initializer provided to: "..name.."; function expected, got "..type(userFunc))
        end
        imports.name = name
        local function exports(export, value)
            local map = exportMap[name]
            if not map then
                map = {}
                exportMap[name] = map
            end
            if type(export) == "table" then
                for k,v in pairs(export) do map[k] = v end -- merge exported table into existing table (needed for sequential exporting calls from one module).
            elseif type(export) == "string" then
                map[export] = value -- a simple one-line export.
            else
                error("WLPM Error: wrong export syntax in module '" .. name .. "'. Use export() with a single object arg or key-value args")
            end
        end
        OnInit(function()
            Require(imports)
            userFunc(importWM, exports, function(val) rawset(_G, name, val) end)
        end)
    end
    --Not needed, but exist for supporting the whole API:
    loadAllWMs , wlpmLoadAllModules = DoNothing, DoNothing
    wlpmDeclareModule , wlpmImportModule , wlpmLoadModule = WM, importWM, importWM
end
