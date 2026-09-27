use common::clock::{color::Color, components};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, single_component_test_module,
};

#[test]
fn check_basic_box() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::BoxComponent {
            pos: (0, 0).into(),
            fill_inside: false,
            color: Color::red(),
            width: 5,
            height: 5,
        })),
        0,
    );
    assert_eq!(
        hex_from_file(get_dump("box1.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_line_box() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::BoxComponent {
            pos: (5, 7).into(),
            color: Color::red(),
            width: 5,
            height: 1,
            fill_inside: false,
        })),
        0,
    );
    assert_eq!(
        hex_from_file(get_dump("box_line.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_box2() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::BoxComponent {
            pos: (10, 20).into(),
            color: Color::red(),
            width: 15,
            height: 7,
            fill_inside: false,
        })),
        0,
    );
    assert_eq!(
        hex_from_file(get_dump("box2.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_line_box_vert() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::BoxComponent {
            pos: (19, 10).into(),
            color: Color::red(),
            width: 1,
            height: 9,
            fill_inside: false,
        })),
        0,
    );
    assert_eq!(
        hex_from_file(get_dump("box_line_vert.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_filled_inside_box() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        &mut single_component_test_module(Box::new(components::BoxComponent {
            pos: (19, 10).into(),
            color: Color::red(),
            width: 10,
            height: 9,
            fill_inside: true,
        })),
        0,
    );
    assert_eq!(
        hex_from_file(get_dump("box_filled.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}
