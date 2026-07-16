use common::structs::{color::Color, components};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, single_component_test_module,
};

#[test]
fn check_basic_box() {
    let mut clock = TestingConnector::new();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module(Box::new(components::BoxComponent {
            pos: (0, 0).into(),
            fill_inside: false,
            color: Color::red(),
            width: 5,
            height: 5,
        })),
    );
    assert_eq!(
        hex_from_file(get_dump("box1.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}
