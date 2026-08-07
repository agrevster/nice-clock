use common::clock::components;
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex,
    single_component_test_module_with_images,
};

#[test]
fn check_basic_image() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module_with_images(
            Box::new(components::ImageComponent {
                pos: (0, 0).into(),
                image_name: "test".to_string(),
            }),
            vec!["test".to_string()],
        ),
    );
    assert_eq!(
        hex_from_file(get_dump("image_basic.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_basic_image2() {
    let mut clock = TestingConnector::default();
    let actual = render_to_hex(
        &mut clock,
        single_component_test_module_with_images(
            Box::new(components::ImageComponent {
                pos: (10, 5).into(),
                image_name: "tree".to_string(),
            }),
            vec!["tree".to_string()],
        ),
    );
    assert_eq!(
        hex_from_file(get_dump("image_basic2.hex")).trim(),
        actual,
        "Component does not match known good hexdump!"
    );
}

#[test]
#[should_panic]
fn check_image_unloaded() {
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        single_component_test_module_with_images(
            Box::new(components::ImageComponent {
                pos: (0, 0).into(),
                image_name: "cat".to_string(),
            }),
            vec!["test".to_string()],
        ),
    );
}

#[test]
#[should_panic]
fn check_image_out_of_bounds() {
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        single_component_test_module_with_images(
            Box::new(components::ImageComponent {
                pos: (30, 5).into(),
                image_name: "cat".to_string(),
            }),
            vec!["test".to_string()],
        ),
    );
}
