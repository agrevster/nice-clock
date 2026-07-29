use common::clock::{color::Color, components};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, single_component_test_module,
};

#[test]
fn check_zero_args_circles() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (10, 10).into(),
            color: Color::red(),
            radius: 0,
            outline_thickness: 0,
        })),
    );

    let empty = hex_from_file(get_dump("empty.hex"));

    assert_eq!(
        empty.clone().trim(),
        actual,
        "Component does not match known good hexdump!"
    );

    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (10, 10).into(),
            color: Color::red(),
            radius: 1,
            outline_thickness: 0,
        })),
    );

    assert_eq!(
        empty.clone().trim(),
        actual,
        "Component does not match known good hexdump!"
    );

    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (10, 10).into(),
            color: Color::red(),
            radius: 0,
            outline_thickness: 1,
        })),
    );

    assert_eq!(
        empty.clone().trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_basic_circle() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (13, 5).into(),
            color: Color::red(),
            radius: 4,
            outline_thickness: 1,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("circle1.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_odd_sized_circle() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (13, 5).into(),
            color: Color::red(),
            radius: 5,
            outline_thickness: 1,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("circle4.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_large_circle() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (10, 20).into(),
            color: Color::red(),
            radius: 11,
            outline_thickness: 1,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("circle3.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_circle_with_nonzero_thickness() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (13, 5).into(),
            color: Color::red(),
            radius: 5,
            outline_thickness: 2,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("circle5.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_circle_filled() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (13, 5).into(),
            color: Color::red(),
            radius: 5,
            outline_thickness: 5,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("circle6.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_circle_filled_partial() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (13, 11).into(),
            color: Color::red(),
            radius: 7,
            outline_thickness: 3,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("circle7.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
#[should_panic]
fn check_circle_filled_too_big() {
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::CircleComponent {
            pos: (13, 11).into(),
            color: Color::red(),
            radius: 7,
            outline_thickness: 8,
        })),
    );
}
