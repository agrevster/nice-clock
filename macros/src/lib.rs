use std::collections::HashSet;

use proc_macro2::{Ident, Literal, Span};
use quote::{format_ident, quote};
use syn::{Data, DeriveInput, Fields, FieldsNamed, parse_macro_input};

extern crate proc_macro;

fn create_set_fn(
    attr_name: &Ident,
    attr_type: &Ident,
    struct_name: &Ident,
    struct_has_field: bool,
) -> proc_macro2::TokenStream {
    let fn_name = format_ident!("set_{attr_name}");

    if struct_has_field {
        quote! {
            fn #fn_name(&mut self, #attr_name: #attr_type){
                self.#attr_name = #attr_name;
            }
        }
    } else {
        let struct_name = struct_name.to_string();
        let field_name = attr_name.to_string();
        let warn_message = Literal::string(&format!(
            "Cannot set field: {} for struct: {} as part of a CustomAnimation, because {} does not have field: {}.",
            field_name, struct_name, struct_name, field_name
        ));
        quote! {
            fn #fn_name(&mut self, #attr_name: #attr_type){
                warn!(#warn_message);
            }
        }
    }
}

#[proc_macro_derive(CustomAnimatable)]
///This macro implements the `CustomAnimatable` trait on a given component.
///
///It generates set methods for following component fields if prescient: `color`, `pos`, `text`. If
///missing, the field will return a function that logs a **no-op warning**.
pub fn custom_animatable_derive(tokens: proc_macro::TokenStream) -> proc_macro::TokenStream {
    let ast = parse_macro_input!(tokens as DeriveInput);
    let struct_ident = &ast.ident;

    if let Data::Struct(struct_data) = &ast.data {
        if let Fields::Named(FieldsNamed {
            named: named_fields,
            ..
        }) = &struct_data.fields
        {
            let field_names = named_fields.iter().fold(HashSet::new(), |mut set, field| {
                set.insert(field.ident.clone().expect(
                    "Should never be None because we are using normal structs not tuple structs!",
                ).to_string());
                set
            });

            let set_color = create_set_fn(
                &Ident::new("color", Span::call_site()),
                &Ident::new("Color", Span::call_site()),
                struct_ident,
                field_names.contains("color"),
            );

            let set_pos = create_set_fn(
                &Ident::new("pos", Span::call_site()),
                &Ident::new("Pos", Span::call_site()),
                struct_ident,
                field_names.contains("pos"),
            );

            let set_text = create_set_fn(
                &Ident::new("text", Span::call_site()),
                &Ident::new("String", Span::call_site()),
                struct_ident,
                field_names.contains("text"),
            );

            quote! {
                impl CustomAnimatable for #struct_ident {
                    #set_color

                    #set_pos

                    #set_text
                }
            }
            .into()
        } else {
            // Struct discrimination! >:(
            syn::Error::new_spanned(
                struct_ident,
                "CustomAnimatable can only be derived by normal structs!",
            )
            .into_compile_error()
            .into()
        }
    } else {
        syn::Error::new_spanned(
            struct_ident,
            "CustomAnimatable can only be derived by structs!",
        )
        .into_compile_error()
        .into()
    }
}
