use common::clock::{color::Color, components, fonts::Font};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, single_component_test_module,
};

#[test]
fn check_basic_text() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::TextComponent {
            pos: (0, 0).into(),
            color: Color::green(),
            text: "Hello World".to_string(),
            font: Font::Font5x5,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("str_hello_world.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
#[should_panic]
fn check_text_out_of_bounds() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::TextComponent {
            pos: (0, 0).into(),
            color: Color::green(),
            text: "Hello world and Hi Mom".to_string(),
            font: Font::Font5x5,
        })),
    );
}

#[test]
fn check_basic_text_near_edge() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::TextComponent {
            pos: (25, 35).into(),
            color: Color::green(),
            text: "Hi mom".to_string(),
            font: Font::Font5x8_2,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("str_hello_almost_max.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_wrapped_long() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::WrappedTextComponent {
            pos: (0, 0).into(),
            color: Color::green(),
            text: "Hi mom and hello dad".to_string(),
            font: Font::Font5x8_2,
            line_spacing: 0,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("strwrap_long.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_wrapped_long_new_line() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::WrappedTextComponent {
            pos: (0, 0).into(),
            color: Color::green(),
            text: "Hi mom and\nhello dad".to_string(),
            font: Font::Font5x8_2,
            line_spacing: 0,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("strwrap_long_nl.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_wrapped_chain() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::WrappedTextComponent {
            pos: (0, 10).into(),
            color: Color::green(),
            text: "1\n2\n3\n4".to_string(),
            font: Font::Font5x8_2,
            line_spacing: 0,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("strwrap_chain.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
#[should_panic]
fn check_wrapped_toolong() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::WrappedTextComponent {
            pos: (10, 10).into(),
            color: Color::green(),
            text: "1\n2\n3\n4".to_string(),
            font: Font::Font5x8_2,
            line_spacing: 0,
        })),
    );
}

#[test]
fn check_wrapped_spacing() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::WrappedTextComponent {
            pos: (0, 10).into(),
            color: Color::green(),
            text: "1:The left\n2:right\n3:Center".to_string(),
            font: Font::Font5x8_2,
            line_spacing: 3,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("strwrap_spacing.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_wrapped_spacing_negative() {
    Font::load_fonts().unwrap();
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::WrappedTextComponent {
            pos: (0, 10).into(),
            color: Color::green(),
            text: "1:The left\n2:right\n3:Center".to_string(),
            font: Font::Font5x8_2,
            line_spacing: -5,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("strwrap_spacing_negative.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}
