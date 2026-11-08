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
                "Export's name is an invalid Luau identifier or is a reserved Luau keyword.",
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

#[cfg(test)]
///*AI was used to help create these tests*
mod test {
    use core::f32;
    use std::collections::HashMap;

    use mlua::{Lua, Value, ffi::luau_BytecodeType::Number};

    use crate::luau::luau_export::{
        LuauConstantExport, LuauConstantSpecBuilder, LuauExportBuilder, LuauFunctionExport,
        LuauFunctionSpecBuilder, LuauType, LuauTypeSpec, LuauTypeTuple, is_luau_keyword,
        is_valid_identifier,
    };

    fn add_export() -> LuauFunctionExport {
        LuauFunctionSpecBuilder::new("add")
            .documentation("Adds two numbers x and y.")
            .param("x", LuauTypeSpec::Number, "The first number to add.")
            .param("y", LuauTypeSpec::Number, "The second number to add.")
            .returns(super::LuauTypeSpec::Number)
            .implement(|_, (x, y): (f32, f32)| Ok(x + y))
            .unwrap()
    }

    fn noop_fn(name: &str) -> LuauFunctionExport {
        LuauFunctionSpecBuilder::new(name)
            .documentation("Does nothing.")
            .implement(|_, ()| Ok(()))
            .unwrap()
    }

    fn pi_export() -> LuauConstantExport {
        LuauConstantSpecBuilder::new("PI")
            .documentation("The ratio of a circle's circumference to its diameter.")
            .constant_type(LuauTypeSpec::Number)
            .implement(std::f32::consts::PI)
            .unwrap()
    }

    fn noop_const(name: &str) -> LuauConstantExport {
        LuauConstantSpecBuilder::new(name)
            .documentation("A constant.")
            .constant_type(LuauTypeSpec::Boolean)
            .implement(false)
            .unwrap()
    }

    fn lua_with_math() -> Lua {
        let mut lua = Lua::new();
        LuauExportBuilder::new("math")
            .function(add_export())
            .unwrap()
            .constant(pi_export())
            .unwrap()
            .build(&mut lua)
            .unwrap();
        lua
    }

    #[test]
    fn valid_identifiers() {
        let valid = vec!["abc", "_", "hello_", "__hello", "YELLING"];
        let invalid = vec![
            "",
            " ",
            "132",
            "1",
            "kebab-kase",
            "new\nline",
            "YAY!",
            " add",
        ];

        for item in valid {
            assert!(is_valid_identifier(item))
        }

        for item in invalid {
            assert!(!is_valid_identifier(item))
        }
    }

    #[test]
    fn luau_keywords() {
        let valid = vec!["abc", "_", "hello_", "__hello", "YELLING", "fn"];
        let invalid = vec![
            "do", "end", "if", "function", "const", "local", "export", "class", "false", "true",
            "nil", "for", "else", "elseif", "and", "or", "not",
        ];

        for item in valid {
            assert!(!is_luau_keyword(item))
        }

        for item in invalid {
            assert!(is_luau_keyword(item))
        }
    }

    #[test]
    fn rust_types_map_to_luau_types() {
        assert_eq!(String::luau_type(), LuauTypeSpec::String);
        assert_eq!(bool::luau_type(), LuauTypeSpec::Boolean);
        assert_eq!(<()>::luau_type(), LuauTypeSpec::Nil);
        assert_eq!(Value::luau_type(), LuauTypeSpec::Any);
        assert_eq!(u8::luau_type(), LuauTypeSpec::Number);
        assert_eq!(i8::luau_type(), LuauTypeSpec::Number);
        assert_eq!(u16::luau_type(), LuauTypeSpec::Number);
        assert_eq!(i16::luau_type(), LuauTypeSpec::Number);
        assert_eq!(u32::luau_type(), LuauTypeSpec::Number);
        assert_eq!(i32::luau_type(), LuauTypeSpec::Number);
        assert_eq!(
            Vec::<bool>::luau_type(),
            LuauTypeSpec::Array(Box::new(LuauTypeSpec::Boolean))
        );
        assert_eq!(
            Vec::<u8>::luau_type(),
            LuauTypeSpec::Array(Box::new(LuauTypeSpec::Number))
        );
        assert_eq!(
            Vec::<String>::luau_type(),
            LuauTypeSpec::Array(Box::new(LuauTypeSpec::String))
        );
        assert_eq!(
            Option::<String>::luau_type(),
            LuauTypeSpec::Optional(Box::new(LuauTypeSpec::String))
        );
        assert_eq!(
            Option::<u32>::luau_type(),
            LuauTypeSpec::Optional(Box::new(LuauTypeSpec::Number))
        );
        assert_eq!(
            HashMap::<String, String>::luau_type(),
            LuauTypeSpec::Map(
                Box::new(LuauTypeSpec::String),
                Box::new(LuauTypeSpec::String)
            )
        );
        assert_eq!(
            HashMap::<f32, String>::luau_type(),
            LuauTypeSpec::Map(
                Box::new(LuauTypeSpec::Number),
                Box::new(LuauTypeSpec::String)
            )
        );
        assert_eq!(
            HashMap::<i16, bool>::luau_type(),
            LuauTypeSpec::Map(
                Box::new(LuauTypeSpec::Number),
                Box::new(LuauTypeSpec::Boolean)
            )
        );
    }

    #[test]
    fn empty_tuple_has_no_params() {
        assert!(<() as LuauTypeTuple>::luau_types().is_empty());
    }

    #[test]
    fn single_element_tuple_has_one_param() {
        assert_eq!(
            <(String,) as LuauTypeTuple>::luau_types(),
            vec![LuauTypeSpec::String]
        );
    }

    #[test]
    fn tuple_parameters_keep_order() {
        assert_eq!(
            <(String, f32, bool) as LuauTypeTuple>::luau_types(),
            vec![
                LuauTypeSpec::String,
                LuauTypeSpec::Number,
                LuauTypeSpec::Boolean
            ]
        );
    }

    #[test]
    fn valid_function() {
        let export = add_export();
        assert_eq!(export.spec.name, "add");
        assert_eq!(export.spec.documentation, "Adds two numbers x and y.");
        assert_eq!(export.spec.return_type, Some(LuauTypeSpec::Number));
        assert_eq!(
            export.spec.params,
            vec![
                (
                    "x".to_string(),
                    LuauTypeSpec::Number,
                    "The first number to add.".to_string()
                ),
                (
                    "y".to_string(),
                    LuauTypeSpec::Number,
                    "The second number to add.".to_string()
                )
            ]
        );
    }

    #[test]
    fn valid_function_no_return_type() {
        let export = noop_fn("test_fn");
        assert_eq!(export.spec.name, "test_fn");
        assert_eq!(export.spec.documentation, "Does nothing.");
        assert_eq!(export.spec.return_type, None);
        assert_eq!(export.spec.params.len(), 0);
    }

    #[test]
    fn nil_return_type_matches_unit_impl() {
        let result = LuauFunctionSpecBuilder::new("ping")
            .documentation("Does nothing.")
            .returns(LuauTypeSpec::Nil)
            .implement(|_, ()| Ok(()));
        assert!(result.is_ok());
    }

    #[test]
    fn optional_return_type() {
        let result = LuauFunctionSpecBuilder::new("find")
            .documentation("Maybe finds something.")
            .returns(LuauTypeSpec::Optional(Box::new(LuauTypeSpec::String)))
            .implement(|_, ()| Ok(Some(String::from("found"))));
        assert!(result.is_ok());
    }

    #[test]
    fn function_must_have_docs() {
        let result = LuauFunctionSpecBuilder::new("who_knows").implement(|_, ()| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn name_cannot_contain_keyword() {
        let result = LuauFunctionSpecBuilder::new("function")
            .documentation("Does nothing.")
            .implement(|_, ()| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn function_names_must_be_valid() {
        for name in ["", "my-func", "1abc", "a b", "a.b"] {
            let result = LuauFunctionSpecBuilder::new(name)
                .documentation("Does nothing.")
                .implement(|_, ()| Ok(()));
            assert!(result.is_err());
        }
    }

    #[test]
    fn mismatch_in_param_count() {
        let result = LuauFunctionSpecBuilder::new("ping")
            .documentation("Does nothing.")
            .param("host", LuauTypeSpec::String, "The host to ping")
            .implement(|_, ()| Ok(()));
        assert!(result.is_err());

        let result = LuauFunctionSpecBuilder::new("ping")
            .documentation("Does nothing.")
            .implement(|_, (_host,): (String,)| Ok(()));
        assert!(result.is_err());
    }
    #[test]
    fn mismatch_in_paraam_type() {
        let result = LuauFunctionSpecBuilder::new("add1")
            .documentation("Does nothing.")
            .param("num", LuauTypeSpec::String, "The number to add 1 to")
            .implement(|_, (_num,): (u8,)| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn mismatch_in_return_type() {
        let result = LuauFunctionSpecBuilder::new("add1")
            .documentation("Does nothing.")
            .returns(LuauTypeSpec::Number)
            .param("num", LuauTypeSpec::Number, "The number to add 1 to")
            .implement(|_, (_num,): (u8,)| Ok(false));
        assert!(result.is_err());
    }

    #[test]
    fn mismatch_in_paraam_type_out_of_order() {
        let result = LuauFunctionSpecBuilder::new("repeat_str")
            .documentation("Does nothing.")
            .param("str", LuauTypeSpec::String, "The text to repeat")
            .param(
                "count",
                LuauTypeSpec::Number,
                "How many times to repeat the text",
            )
            .implement(|_, (_num, _str): (u8, String)| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn duplicate_param_names() {
        let result = LuauFunctionSpecBuilder::new("test_fn")
            .documentation("Does nothing.")
            .param("x", LuauTypeSpec::String, "The text to repeat")
            .param("x", LuauTypeSpec::String, "The text to repeat")
            .implement(|_, (_str, _str1): (String, String)| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn param_name_must_be_valid() {
        let result = LuauFunctionSpecBuilder::new("ping")
            .documentation("Does nothing.")
            .param(" x", LuauTypeSpec::Number, "x")
            .implement(|_, (_x,): (u32,)| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn mismatch_in_return_type_with_unit() {
        let result = LuauFunctionSpecBuilder::new("print")
            .documentation("Does nothing.")
            .returns(LuauTypeSpec::Array(Box::new(LuauTypeSpec::Boolean)))
            .implement(|_, ()| Ok(()));
        assert!(result.is_err());
    }

    #[test]
    fn valid_constants() {
        assert!(
            LuauConstantSpecBuilder::new("PI")
                .documentation("A number.")
                .constant_type(LuauTypeSpec::Number)
                .implement(f32::consts::PI)
                .is_ok()
        );
        assert!(
            LuauConstantSpecBuilder::new("VERSION")
                .documentation("A string.")
                .constant_type(LuauTypeSpec::String)
                .implement(String::from("1.0"))
                .is_ok()
        );
        assert!(
            LuauConstantSpecBuilder::new("DEBUG")
                .documentation("A bool.")
                .constant_type(LuauTypeSpec::Boolean)
                .implement(false)
                .is_ok()
        );
        assert!(
            LuauConstantSpecBuilder::new("NAMES")
                .documentation("An array.")
                .constant_type(LuauTypeSpec::Array(Box::new(LuauTypeSpec::String)))
                .implement(vec![String::from("a")])
                .is_ok()
        );
    }

    #[test]
    fn valid_constant_in_module() {
        let export = pi_export();
        assert_eq!(export.spec.name, "PI");
        assert_eq!(export.spec.constant_type, LuauTypeSpec::Number);
        assert!(!export.spec.documentation.is_empty());
    }

    #[test]
    fn constant_requires_docs() {
        let result = LuauConstantSpecBuilder::new("one")
            .constant_type(LuauTypeSpec::Number)
            .implement(1);
        assert!(result.is_err());
    }

    #[test]
    fn constant_requires_type() {
        let result = LuauConstantSpecBuilder::new("one")
            .documentation("A number.")
            .implement(1);
        assert!(result.is_err());
    }

    #[test]
    fn constant_name_must_not_be_luau_keyword() {
        let result = LuauConstantSpecBuilder::new("end")
            .documentation("A number.")
            .constant_type(LuauTypeSpec::Number)
            .implement(2);
        assert!(result.is_err());
    }

    #[test]
    fn constant_name_must_be_valid_luau_identifier() {
        let result = LuauConstantSpecBuilder::new(".test")
            .documentation("A number.")
            .constant_type(LuauTypeSpec::Number)
            .implement(2);
        assert!(result.is_err());
    }

    #[test]
    fn type_mismatch_with_nested_types() {
        let result = LuauConstantSpecBuilder::new("NAMES")
            .documentation("An array.")
            .constant_type(LuauTypeSpec::Array(Box::new(LuauTypeSpec::Number)))
            .implement(vec![String::from("a")]);
        assert!(result.is_err());
    }

    #[test]
    fn module_no_duplicates() {
        let builder = LuauExportBuilder::new("module")
            .function(noop_fn("a"))
            .unwrap()
            .function(noop_fn("b"))
            .unwrap()
            .constant(noop_const("C"))
            .unwrap();
        assert_eq!(builder.functions.len(), 2);
        assert_eq!(builder.constants.len(), 1);
    }

    #[test]
    fn case_is_different() {
        let result = LuauExportBuilder::new("module")
            .function(noop_fn("now"))
            .unwrap()
            .function(noop_fn("Now"));
        assert!(result.is_ok());
    }

    #[test]
    fn no_duplicate_function_names() {
        let result = LuauExportBuilder::new("module")
            .function(noop_fn("a"))
            .unwrap()
            .function(noop_fn("a"));
        assert!(result.is_err());
    }
    #[test]
    fn no_duplicate_constants() {
        let result = LuauExportBuilder::new("module")
            .constant(noop_const("a"))
            .unwrap()
            .constant(noop_const("a"));
        assert!(result.is_err());
    }
    #[test]
    fn no_duplicate_const_and_fn() {
        let result = LuauExportBuilder::new("module")
            .constant(noop_const("a"))
            .unwrap()
            .function(noop_fn("a"));
        assert!(result.is_err());
    }
    #[test]
    fn no_duplicate_fn_and_const() {
        let result = LuauExportBuilder::new("module")
            .function(noop_fn("a"))
            .unwrap()
            .constant(noop_const("a"));
        assert!(result.is_err());
    }

    #[test]
    fn module_exposes_exports() {
        let luau = lua_with_math();
        let sum: u8 = luau.load("return math.add(2, 3)").eval().unwrap();
        assert_eq!(sum, 5);

        let pi: f32 = luau.load("return math.PI").eval().unwrap();
        assert_eq!(pi, std::f32::consts::PI);
    }

    #[test]
    fn module_readonly() {
        let luau = lua_with_math();
        assert!(luau.load("math.PI = 3").exec().is_err());
        assert!(luau.load("math.add = nil").exec().is_err());
        assert!(luau.load("math.extra = 1").exec().is_err());

        let pi: f32 = luau.load("return math.PI").eval().unwrap();
        assert_eq!(pi, std::f32::consts::PI);
    }

    #[test]
    fn built_module_does_not_leak_members_into_globals() {
        let lua = lua_with_math();
        assert!(lua.globals().get::<Value>("add").unwrap() == Value::Nil);
        assert!(lua.globals().get::<Value>("PI").unwrap() == Value::Nil);
        assert!(lua.globals().get::<Value>("math").unwrap() != Value::Nil);
    }

    #[test]
    fn script_passing_the_wrong_argument_type_gets_an_error() {
        let luau = lua_with_math();
        assert!(
            luau.load(r#"return math.add("x", 1)"#)
                .eval::<u8>()
                .is_err()
        );
    }

    #[test]
    fn function_setup() {
        let mut lua = Lua::new();
        let len = LuauFunctionSpecBuilder::new("len")
            .documentation("Measures text.")
            .param("text", LuauTypeSpec::String, "The text.")
            .returns(LuauTypeSpec::Number)
            .implement(|_, (text,): (String,)| Ok(text.len() as u32))
            .unwrap();
        LuauExportBuilder::new("strings")
            .function(len)
            .unwrap()
            .build(&mut lua)
            .unwrap();

        let n: u32 = lua.load(r#"return strings.len("abc")"#).eval().unwrap();
        assert_eq!(n, 3);
    }

    #[test]
    fn optional_param_function() {
        let mut luau = Lua::new();
        let hello = LuauFunctionSpecBuilder::new("hello")
            .documentation("Greets someone.")
            .param(
                "name",
                LuauTypeSpec::Optional(Box::new(LuauTypeSpec::String)),
                "Who to greet.",
            )
            .returns(LuauTypeSpec::String)
            .implement(|_, (name,): (Option<String>,)| {
                Ok(format!(
                    "Hello, {}!",
                    name.unwrap_or_else(|| "world".into())
                ))
            })
            .unwrap();
        LuauExportBuilder::new("greet")
            .function(hello)
            .unwrap()
            .build(&mut luau)
            .unwrap();

        let default: String = luau.load("return greet.hello()").eval().unwrap();
        let named: String = luau.load(r#"return greet.hello("Sam")"#).eval().unwrap();
        assert_eq!(default, "Hello, world!");
        assert_eq!(named, "Hello, Sam!");
    }

    #[test]
    fn array_table_in_luau() {
        let mut luau = Lua::new();
        let names = LuauConstantSpecBuilder::new("NAMES")
            .documentation("Some names.")
            .constant_type(LuauTypeSpec::Array(Box::new(LuauTypeSpec::String)))
            .implement(vec![String::from("a"), String::from("b")])
            .unwrap();
        LuauExportBuilder::new("config")
            .constant(names)
            .unwrap()
            .build(&mut luau)
            .unwrap();

        let len: f64 = luau.load("return #config.NAMES").eval().unwrap();
        let first: String = luau.load("return config.NAMES[1]").eval().unwrap();
        assert_eq!(len, 2.0);
        assert_eq!(first, "a");
    }

    #[test]
    fn global_export() {
        let mut luau = Lua::new();
        LuauExportBuilder::new("global")
            .function(add_export())
            .unwrap()
            .constant(pi_export())
            .unwrap()
            .build_global(&mut luau)
            .unwrap();

        let sum: u8 = luau.load("return add(1, 2)").eval().unwrap();
        let pi: f32 = luau.load("return PI").eval().unwrap();
        assert_eq!(sum, 3);
        assert_eq!(pi, std::f32::consts::PI);
        assert!(luau.globals().get::<Value>("global").unwrap() == Value::Nil);
    }

    #[test]
    fn invalid_export_not_pushed() {
        for name in ["end", "my-mod", "", "1abc", "type"] {
            let mut luau = Lua::new();
            let result = LuauExportBuilder::new(name)
                .function(noop_fn("a"))
                .unwrap()
                .build(&mut luau);
            assert!(result.is_err());
            let result = LuauExportBuilder::new(name)
                .function(noop_fn("a"))
                .unwrap()
                .build_global(&mut luau);
            assert!(result.is_err());
        }
    }
}
