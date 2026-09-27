use std::num::{NonZeroU8, NonZeroU32};

use common::clock::{
    color::Color,
    components::{self, Animation, AnimationKeyframe},
};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, test_module,
};

#[test]
fn check_basic_animation() {
    let mut clock = TestingConnector::default();
    let module = &mut test_module(
        vec![Box::new(components::TileComponent {
            pos: (9, 5).into(),
            color: Color::red(),
        })],
        vec![
            Animation::new(
                vec![0],
                vec![
                    AnimationKeyframe::at(0).color(Color::red()),
                    AnimationKeyframe::at(1).color(Color::blue()),
                ],
                NonZeroU8::new(1).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
        ],
        vec![],
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );

    //Animation should roll back because we repeat
    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 2),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_basic_animation_no_loop() {
    let mut clock = TestingConnector::default();
    let module = &mut test_module(
        vec![Box::new(components::TileComponent {
            pos: (9, 5).into(),
            color: Color::red(),
        })],
        vec![
            Animation::new(
                vec![0],
                vec![
                    AnimationKeyframe::at(0).color(Color::red()),
                    AnimationKeyframe::at(1).color(Color::blue()),
                ],
                NonZeroU8::new(1).unwrap(),
                NonZeroU32::new(1).unwrap(),
                false,
            )
            .unwrap(),
        ],
        vec![],
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );

    //No looping
    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_multi_component_animation() {
    let mut clock = TestingConnector::default();
    let module = &mut test_module(
        vec![
            Box::new(components::TileComponent {
                pos: (9, 5).into(),
                color: Color::red(),
            }),
            Box::new(components::TileComponent {
                pos: (9, 6).into(),
                color: Color::red(),
            }),
        ],
        vec![
            Animation::new(
                vec![0, 1],
                vec![
                    AnimationKeyframe::at(0).color(Color::red()),
                    AnimationKeyframe::at(1).color(Color::blue()),
                ],
                NonZeroU8::new(1).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
        ],
        vec![],
    );

    assert_eq!(
        hex_from_file(get_dump("animation_multi_red.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_multi_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_multi_component_animation_diff() {
    let mut clock = TestingConnector::default();
    let module = &mut test_module(
        vec![
            Box::new(components::TileComponent {
                pos: (9, 5).into(),
                color: Color::red(),
            }),
            Box::new(components::TileComponent {
                pos: (9, 6).into(),
                color: Color::blue(),
            }),
        ],
        vec![
            Animation::new(
                vec![0],
                vec![
                    AnimationKeyframe::at(0).color(Color::red()),
                    AnimationKeyframe::at(1).color(Color::blue()),
                ],
                NonZeroU8::new(1).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
            Animation::new(
                vec![1],
                vec![
                    AnimationKeyframe::at(0).color(Color::blue()),
                    AnimationKeyframe::at(1).color(Color::red()),
                ],
                NonZeroU8::new(1).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
        ],
        vec![],
    );

    assert_eq!(
        hex_from_file(get_dump("animation_diff0.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_diff1.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_diff0.hex")).trim(),
        render_to_hex(&mut clock, module, 2),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_diff1.hex")).trim(),
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_basic_animation_slower() {
    let mut clock = TestingConnector::default();
    let module = &mut test_module(
        vec![Box::new(components::TileComponent {
            pos: (9, 5).into(),
            color: Color::red(),
        })],
        vec![
            Animation::new(
                vec![0],
                vec![
                    AnimationKeyframe::at(0).color(Color::red()),
                    AnimationKeyframe::at(1).color(Color::blue()),
                ],
                NonZeroU8::new(2).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
        ],
        vec![],
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 2),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );

    //Animation should roll back because we repeat
    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_red.hex")).trim(),
        render_to_hex(&mut clock, module, 5),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_basic_blue.hex")).trim(),
        render_to_hex(&mut clock, module, 6),
        "Component does not match known good hexdump!"
    );
}

#[test]
#[should_panic]
fn animation_fails_with_no_keyframes() {
    Animation::new(
        vec![1],
        vec![],
        NonZeroU8::new(2).unwrap(),
        NonZeroU32::new(1).unwrap(),
        true,
    )
    .unwrap();
}

#[test]
#[should_panic]
fn animation_fails_with_invalid_component() {
    let mut clock = TestingConnector::default();
    render_to_hex(
        &mut clock,
        &mut test_module(
            vec![Box::new(components::TileComponent {
                pos: (9, 5).into(),
                color: Color::red(),
            })],
            vec![
                Animation::new(
                    vec![1],
                    vec![
                        AnimationKeyframe::at(0).color(Color::red()),
                        AnimationKeyframe::at(1).color(Color::blue()),
                    ],
                    NonZeroU8::new(1).unwrap(),
                    NonZeroU32::new(1).unwrap(),
                    true,
                )
                .unwrap(),
            ],
            vec![],
        ),
        0,
    );
}

#[test]
fn check_multi_component_animation_desync() {
    let mut clock = TestingConnector::default();
    let module = &mut test_module(
        vec![
            Box::new(components::TileComponent {
                pos: (9, 5).into(),
                color: Color::red(),
            }),
            Box::new(components::TileComponent {
                pos: (9, 6).into(),
                color: Color::blue(),
            }),
        ],
        vec![
            Animation::new(
                vec![0],
                vec![
                    AnimationKeyframe::at(0).color(Color::red()),
                    AnimationKeyframe::at(1).color(Color::blue()),
                ],
                NonZeroU8::new(2).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
            Animation::new(
                vec![1],
                vec![
                    AnimationKeyframe::at(0).color(Color::blue()),
                    AnimationKeyframe::at(1).color(Color::red()),
                ],
                NonZeroU8::new(1).unwrap(),
                NonZeroU32::new(1).unwrap(),
                true,
            )
            .unwrap(),
        ],
        vec![],
    );

    assert_eq!(
        hex_from_file(get_dump("animation_desync0.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_desync1.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_desync2.hex")).trim(),
        render_to_hex(&mut clock, module, 2),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("animation_desync3.hex")).trim(),
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("animation_desync4.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );
}
