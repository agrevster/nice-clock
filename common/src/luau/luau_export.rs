use std::{
    collections::{BTreeMap, HashMap},
    iter::zip,
};

use mlua::{FromLuaMulti, Function as LuaFunction, IntoLua, IntoLuaMulti, Lua, Value};
use strum::Display;

use crate::{VoidClockResult, clock::errors::ClockError};

///Used to handle build a Luau export.
///Create with `LuauExportBuilder::new()`
pub struct LuauExportBuilder {
    name: String,
    functions: BTreeMap<String, LuauFunctionExport>,
    constants: BTreeMap<String, LuauConstantExport>,
}
impl LuauExportBuilder {
    ///Creates a `LuauExportBuilder` with the given `name`.
    pub fn new(name: impl Into<String>) -> LuauExportBuilder {
        LuauExportBuilder {
            name: name.into(),
            functions: BTreeMap::new(),
            constants: BTreeMap::new(),
        }
    }

    ///Adds a new `LuauFunctionExport` to the `LuauExportBuilder`.
    ///Returns an error if the name of the function already exists in the export.
    pub fn function(
        mut self,
        function: LuauFunctionExport,
    ) -> Result<LuauExportBuilder, ClockError> {
        let fn_name = function.spec.name.clone();

        if self.functions.contains_key(&fn_name) || self.constants.contains_key(&fn_name) {
            return Err(ClockError::luau_spec_validation(
                "An item with this name already exists in the export module.",
            ));
        }

        self.functions.insert(fn_name, function);
        Ok(self)
    }

    ///Adds a new `LuauConstantExport` to the `LuauExportBuilder`.
    ///Returns an error if the name of the constant already exists in the export.
    pub fn constant(
        mut self,
        constant: LuauConstantExport,
    ) -> Result<LuauExportBuilder, ClockError> {
        let const_name = constant.spec.name.clone();

        if self.functions.contains_key(&const_name) || self.constants.contains_key(&const_name) {
            return Err(ClockError::luau_spec_validation(
                "An item with this name already exists in the export module.",
            ));
        }
        self.constants.insert(const_name, constant);
        Ok(self)
    }

    fn validate_export_name(&self) -> VoidClockResult {
        if is_luau_keyword(&self.name) || !is_valid_identifier(&self.name) {
            return Err(ClockError::luau_spec_validation(
                "Constant's name is an invalid Luau identifier or is a reserved Luau keyword.",
            ));
        }
        Ok(())
    }

    ///Attempts to convert the `LuauExportBuilder` into a luau export by pushing all functions and
    ///constants to a luau table with the name of `LuauExportBuilder.name`.
    pub fn build(self, lua: &mut Lua) -> VoidClockResult {
        self.validate_export_name()?;
        let table = lua.create_table()?;

        for (name, constant) in self.constants {
            table.set(name, (constant.implementation)(lua)?)?
        }

        for (name, func) in self.functions {
            table.set(name, (func.implementation)(lua)?)?
        }

        table.set_readonly(true);

        lua.globals().set(self.name, table)?;

        Ok(())
    }

    ///Attempts to convert the `LuauExportBuilder` into a luau export by pushing all functions and
    ///constants to the luau global table.
    pub fn build_global(self, lua: &mut Lua) -> VoidClockResult {
        self.validate_export_name()?;

        for (name, constant) in self.constants {
            lua.globals().set(name, (constant.implementation)(lua)?)?
        }

        for (name, func) in self.functions {
            lua.globals().set(name, (func.implementation)(lua)?)?
        }

        Ok(())
    }
}

//
// Types
//

#[derive(Debug, PartialEq, Display, Clone)]
pub enum LuauTypeSpec {
    Any,
    Nil,
    Boolean,
    Number,
    String,
    ///T?
    Optional(Box<LuauTypeSpec>),
    ///X | Y | Z
    Union(Vec<LuauTypeSpec>),
    /// {T}
    Array(Box<LuauTypeSpec>),
    /// {K: V}
    Map(Box<LuauTypeSpec>, Box<LuauTypeSpec>),
    /// {a: T, b: U}
    Table(Vec<(String, LuauTypeSpec)>),
    StringLiteral(&'static str),
    Function(Box<LuauFunctionSpec>),
    Class(&'static str), // Class name use for static user data
}

///Trait used to show which Rust types can be represent as `LuauTypeSpec`.
pub trait LuauType {
    ///Returns the `LuauTypeSpec` used to represent the given type.
    fn luau_type() -> LuauTypeSpec;
}

trait LuauTypeTuple {
    fn luau_types() -> Vec<LuauTypeSpec>;
}

impl LuauTypeTuple for () {
    fn luau_types() -> Vec<LuauTypeSpec> {
        vec![]
    }
}

macro_rules! impl_luau_types {
    ($($t:ident),+) => {
        impl<$($t: LuauType),+> LuauTypeTuple for ($($t,)+) {
            fn luau_types() -> Vec<LuauTypeSpec> { vec![$($t::luau_type()),+] }
        }
    };
}

impl_luau_types!(A);
impl_luau_types!(A, B);
impl_luau_types!(A, B, C);
impl_luau_types!(A, B, C, D);
impl_luau_types!(A, B, C, D, E);
impl_luau_types!(A, B, C, D, E, F);
impl_luau_types!(A, B, C, D, E, F, G);
impl_luau_types!(A, B, C, D, E, F, G, H);
impl_luau_types!(A, B, C, D, E, F, G, H, I);
impl_luau_types!(A, B, C, D, E, F, G, H, I, J);

impl LuauType for Value {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Any
    }
}
impl LuauType for () {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Nil
    }
}
impl<T: LuauType> LuauType for Vec<T> {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Array(Box::new(T::luau_type()))
    }
}
impl<T: LuauType> LuauType for Option<T> {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Optional(Box::new(T::luau_type()))
    }
}
impl<K: LuauType, V: LuauType> LuauType for HashMap<K, V> {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Map(Box::new(K::luau_type()), Box::new(V::luau_type()))
    }
}
impl LuauType for String {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::String
    }
}
impl LuauType for bool {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Boolean
    }
}
impl LuauType for u8 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for i8 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for u16 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for i16 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for u32 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for i32 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for f32 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}
impl LuauType for f64 {
    fn luau_type() -> LuauTypeSpec {
        LuauTypeSpec::Number
    }
}

///Returns whether or not the given `str` is a valid Luau identifier
fn is_valid_identifier(str: &str) -> bool {
    let mut chars = str.chars();
    matches!(chars.next(), Some(c) if c.is_ascii_alphabetic() || c == '_')
        && chars.all(|c| c.is_ascii_alphanumeric() || c == '_')
}

///Returns if the given `str` is a Luau keyword.
fn is_luau_keyword(str: &str) -> bool {
    matches!(
        str,
        "and"
            | "break"
            | "class"
            | "continue"
            | "declare"
            | "do"
            | "else"
            | "elseif"
            | "end"
            | "export"
            | "extends"
            | "false"
            | "for"
            | "function"
            | "if"
            | "in"
            | "local"
            | "const"
            | "nil"
            | "not"
            | "or"
            | "repeat"
            | "return"
            | "self"
            | "then"
            | "true"
            | "type"
            | "typeof"
            | "until"
            | "while"
    )
}

//
// Functions
//

///Used to represent a Luau function used by nice clock `LuauFunctionSpec` contains the function's
///documentation and `implementation` contains the Rust code that is run on function call.
#[allow(clippy::type_complexity)]
pub struct LuauFunctionExport {
    spec: LuauFunctionSpec,
    implementation: Box<dyn FnOnce(&Lua) -> mlua::Result<LuaFunction>>,
}

///Used to create a `LuauFunctionSpec`.
struct LuauFunctionSpecBuilder {
    ///The function's name.
    name: String,
    ///A short description of what the function does.
    documentation: Option<String>,
    ///The return type of the function
    return_type: Option<LuauTypeSpec>,
    ///The functions parameters stored as a tuple: (name, return type, docs).
    params: Vec<(String, LuauTypeSpec, String)>,
}
///Contains the documentation of a `LuauFunctionExport`.
///Created by `LuauExportBuilder`.
///Can be converted to `LuauFunctionExport` by calling `.implement`.
#[derive(Debug, PartialEq, Clone)]
pub struct LuauFunctionSpec {
    ///The function's name.
    name: String,
    ///A short description of what the function does.
    documentation: String,
    ///The return type of the function.
    return_type: Option<LuauTypeSpec>,
    ///The functions parameters stored as a tuple: (name, return type, docs).
    params: Vec<(String, LuauTypeSpec, String)>,
}

impl LuauFunctionSpecBuilder {
    ///Creates a new `LuauFunctionSpecBuilder` used to create a `LuauFunctionSpec` with the given `name`.
    pub fn new(name: impl Into<String>) -> Self {
        LuauFunctionSpecBuilder {
            name: name.into(),
            documentation: None,
            return_type: None,
            params: vec![],
        }
    }

    ///Sets the function's `documentation` to the given string.
    pub fn documentation(mut self, documentation: impl Into<String>) -> LuauFunctionSpecBuilder {
        self.documentation = Some(documentation.into());
        self
    }

    ///Sets the function's `return_type` to the given string.
    pub fn returns(mut self, return_type: LuauTypeSpec) -> LuauFunctionSpecBuilder {
        self.return_type = Some(return_type);
        self
    }

    ///Adds a new parameter to the function with the given `name`, `return_type` and
    ///`documentation`.
    pub fn param(
        mut self,
        name: impl Into<String>,
        param_type: LuauTypeSpec,
        documentation: impl Into<String>,
    ) -> LuauFunctionSpecBuilder {
        self.params
            .push((name.into(), param_type, documentation.into()));
        self
    }

    ///Converts a `LuauFunctionSpecBuilder` -> `LuauFunctionSpec` validating each required item is present.
    ///Returns a `LuauSpecBuilderError` if a required item is missing.
    pub fn build(self) -> Result<LuauFunctionSpec, ClockError> {
        Ok(LuauFunctionSpec {
            name: self.name,
            documentation: self
                .documentation
                .ok_or_else(|| ClockError::luau_spec_builder_missing_field("documentation"))?,
            return_type: self.return_type,
            params: self.params,
        })
    }

    pub fn implement<A, R, F>(self, f: F) -> Result<LuauFunctionExport, ClockError>
    where
        A: FromLuaMulti + 'static + LuauTypeTuple,
        R: IntoLuaMulti + 'static + LuauType,
        F: Fn(&Lua, A) -> mlua::Result<R> + 'static,
    {
        let spec = self.build()?;
        spec.validate(A::luau_types(), R::luau_type())?;

        Ok(LuauFunctionExport {
            spec,
            implementation: Box::new(move |lua| lua.create_function(f)),
        })
    }
}

impl LuauFunctionSpec {
    ///Validates a given `LuauFunctionSpec` matches the given implementation.
    ///# This functions asserts the following:
    ///
    ///* The number of arguments in the type spec matches the number of arguments in the implementation.
    ///* The return value of the type spec matches the return type of the implementation.
    ///* The type of arguments in the type spec matches the type of arguments in the implementation.
    ///* Each argument name appears only once.
    ///* The function's name is a valid luau identifier.
    ///* Argument names are valid Luau identifiers.
    ///* Documentation is specified for the function.
    ///* Documentation is specified for each parameter.
    fn validate(
        &self,
        param_types: Vec<LuauTypeSpec>,
        return_type: LuauTypeSpec,
    ) -> VoidClockResult {
        //The number of arguments in the type spec matches the number of arguments in the implementation.
        if self.params.len() != param_types.len() {
            return Err(ClockError::luau_spec_validation(format!(
                "Mismatch in argument length between spec: {} and implementation: {}.",
                self.params.len(),
                param_types.len()
            )));
        }
        //The return value of the type spec matches the return type of the implementation.
        let spec_return_type = self.return_type.clone().unwrap_or(LuauTypeSpec::Nil);
        if spec_return_type != return_type {
            return Err(ClockError::luau_spec_validation(format!(
                "Mismatch in function return types between spec: {} and implementation: {}.",
                spec_return_type, return_type
            )));
        }

        //Documentation is specified for the function.
        if self.documentation.is_empty() {
            return Err(ClockError::luau_spec_validation(
                "Function documentation is required!",
            ));
        }

        //The function's name is a valid luau identifier.
        if is_luau_keyword(&self.name) || !is_valid_identifier(&self.name) {
            return Err(ClockError::luau_spec_validation(
                "Function name is an invalid Luau identifier or is a reserved Luau keyword.",
            ));
        }

        //Each argument name appears only once.
        for (i, (name, ..)) in self.params.iter().enumerate() {
            if self.params[..i].iter().any(|(prev, ..)| prev == name) {
                return Err(ClockError::luau_spec_validation(format!(
                    "Duplicate parameter name: {name}."
                )));
            }
        }

        //The type of arguments in the type spec matches the type of arguments in the implementation.
        //Documentation is specified for each parameter.
        //No reserved keywords are used for the function's parameters.
        //* Argument names are valid Luau identifiers.
        for ((spec_param_name, spec_param_type, spec_param_docs), implementation_param_type) in
            zip(self.params.iter(), param_types)
        {
            //Documentation is specified for the function.
            if spec_param_docs.is_empty() {
                return Err(ClockError::luau_spec_validation(format!(
                    "Parameter: {spec_param_name} is missing documentation."
                )));
            }

            //No reserved keywords are used for the function's parameters.
            if is_luau_keyword(spec_param_name) || !is_valid_identifier(spec_param_name) {
                return Err(ClockError::luau_spec_validation(format!(
                    "Parameter: {spec_param_name} contained reserved Luau keyword or is an invalid luau identifier."
                )));
            }

            //The type of arguments in the type spec matches the type of arguments in the implementation.
            if spec_param_type != &implementation_param_type {
                return Err(ClockError::luau_spec_validation(format!(
                    "Parameter type mismatch between spec: {spec_param_type} and implementation: {implementation_param_type}."
                )));
            }
        }

        Ok(())
    }
}

//
// Constants
//

///Used to represent a Luau constant used by nice clock `LuauConstantSpec` contains the constant's
///documentation and `implementation` contains the Rust code that is run to compute the constant.
#[allow(clippy::type_complexity)]
pub struct LuauConstantExport {
    spec: LuauConstantSpec,
    implementation: Box<dyn FnOnce(&Lua) -> mlua::Result<Value>>,
}
///Used to create a `LuauConstantSpec`.
struct LuauConstantSpecBuilder {
    ///The constant's name.
    name: String,
    ///A short description of what the constant is.
    documentation: Option<String>,
    ///The type of the constant.
    constant_type: Option<LuauTypeSpec>,
}

///Contains the documentation of a `LuauConstantExport`.
///Created by `LuauExportBuilder`.
///Can be converted to `LuauConstantExport` by calling `.implement`.
#[derive(Debug, PartialEq, Clone)]
struct LuauConstantSpec {
    ///The constant's name.
    name: String,
    ///A short description of what the constant is.
    documentation: String,
    ///The type of the constant.
    constant_type: LuauTypeSpec,
}

impl LuauConstantSpecBuilder {
    ///Creates a new `LuauFunctionSpecBuilder` used to create a `LuauConstantSpec` with the given `name`.
    pub fn new(name: impl Into<String>) -> Self {
        LuauConstantSpecBuilder {
            name: name.into(),
            documentation: None,
            constant_type: None,
        }
    }

    ///Sets the function's `documentation` to the given string.
    pub fn documentation(mut self, documentation: impl Into<String>) -> LuauConstantSpecBuilder {
        self.documentation = Some(documentation.into());
        self
    }

    ///Sets the function's `return_type` to the given string.
    pub fn constant_type(mut self, constant_type: LuauTypeSpec) -> LuauConstantSpecBuilder {
        self.constant_type = Some(constant_type);
        self
    }

    ///Converts a `LuauConstantSpecBuilder` -> `LuauConstantSpec` validating each required item is present.
    ///Returns a `LuauSpecBuilderError` if a required item is missing.
    pub fn build(self) -> Result<LuauConstantSpec, ClockError> {
        Ok(LuauConstantSpec {
            name: self.name,
            documentation: self
                .documentation
                .ok_or_else(|| ClockError::luau_spec_builder_missing_field("documentation"))?,
            constant_type: self
                .constant_type
                .ok_or_else(|| ClockError::luau_spec_builder_missing_field("constant_type"))?,
        })
    }

    pub fn implement<T>(self, value: T) -> Result<LuauConstantExport, ClockError>
    where
        T: IntoLua + LuauType + 'static,
    {
        let spec = self.build()?;
        spec.validate(T::luau_type())?;
        Ok(LuauConstantExport {
            spec,
            implementation: Box::new(move |lua| value.into_lua(lua)),
        })
    }
}

impl LuauConstantSpec {
    ///Validates a given `LuauConstantSpec` matches the given implementation.
    ///# This functions asserts the following:
    ///
    ///* Documentation is specified for the constant's spec.
    ///* The spec's name is a valid luau identifier.
    ///* The spec's type matches the implementation's type.
    fn validate(&self, implementation_type: LuauTypeSpec) -> VoidClockResult {
        //Documentation is specified for the constant's spec.
        if self.documentation.is_empty() {
            return Err(ClockError::luau_spec_validation(
                "Constant documentation is required!",
            ));
        }
        //The spec's name is a valid luau identifier.
        if is_luau_keyword(&self.name) || !is_valid_identifier(&self.name) {
            return Err(ClockError::luau_spec_validation(
                "Constant's name is an invalid Luau identifier or is a reserved Luau keyword.",
            ));
        }

        //The spec's name is not a reserved Luau keyword.
        if is_luau_keyword(&self.name) {
            return Err(ClockError::luau_spec_validation(
                "Constant's name contains a reserved Luau keyword.",
            ));
        }

        //The spec's type matches the implementation's type.
        if self.constant_type != implementation_type {
            return Err(ClockError::luau_spec_validation(format!(
                "Mismatch in constant return types between spec: {} and implementation: {}.",
                self.constant_type, implementation_type
            )));
        }

        Ok(())
    }
}
