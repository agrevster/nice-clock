use mlua::{Lua, LuaOptions, StdLib};

use crate::{VoidClockResult, utils::LogUnwrap};

///A struct used to create `ClockModule` from luau.
pub struct ModuleLoader {
    lua: Lua,
}

impl ModuleLoader {
    pub fn new() -> ModuleLoader {
        let lua = Lua::new_with(
            StdLib::TABLE & StdLib::STRING & StdLib::MATH & StdLib::OS & StdLib::UTF8,
            LuaOptions::new().catch_rust_panics(true),
        )
        .unwrap_and_log("Failed to setup Luau!");

        lua.globals()
            .set("require", mlua::Nil)
            .unwrap_and_log("Failed to disable the require function!");

        lua.sandbox(true)
            .unwrap_and_log("Failed to enable luau sandboxing!");

        ModuleLoader { lua }
    }

    fn eval(self, code: &str) -> VoidClockResult {
        self.lua.load(code).set_name("ModuleLoader.eval").exec()?;
        Ok(())
    }
}

impl Default for ModuleLoader {
    fn default() -> Self {
        Self::new()
    }
}

#[test]
///Ensures the require function does not work so we can't include other files into our Luau.
fn require_function_should_be_disabled() {
    use crate::clock::errors::{ClockError, ClockLuauError};
    let loader = ModuleLoader::new();
    if let Err(ClockError::LuauError(ClockLuauError::LuauCodeError(msg))) =
        loader.eval("require(\"\")")
    {
        assert!(msg.to_string().contains("attempt to call a nil value"))
    } else {
        panic!("Require failed to disable!")
    }
}
