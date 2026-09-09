use std::str::FromStr;

use common::clock::{color::Color, components, fonts::Font};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, single_component_test_module,
};
use strum::VariantNames;

#[test]
fn check_chars_with_l() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    for font_str in Font::VARIANTS {
        let font_enum = Font::from_str(font_str).expect("Failed to find font with given name!");
        let actual = render_to_hex(
            &mut clock,
            &mut single_component_test_module(Box::new(components::CharComponent {
                pos: (9, 5).into(),
                color: Color::blue(),
                chr: 'L',
                font: font_enum,
            })),
        );
        let filename = font_str.replace("Font", "");
        assert_eq!(
            hex_from_file(get_dump(&format!("char_{filename}.hex"))).trim(),
            actual,
            "Component does not match known good hexdump!"
        );
    }
}

#[test]
#[should_panic]
fn check_char_out_of_bounds() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::CharComponent {
            pos: (0, 61).into(),
            color: Color::green(),
            chr: '}',
            font: Font::Font6x12,
        })),
    );
}

#[test]
fn check_invalid_char_does_default() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::CharComponent {
            pos: (0, 20).into(),
            color: Color::green(),
            chr: 'æ',
            font: Font::Font5x5,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("char_default.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}
