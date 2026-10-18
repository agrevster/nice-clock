use std::{
    cell::Cell,
    num::{NonZeroU8, NonZeroU32},
};

use common::clock::{color::Color, components::HorizontalScrollingTextComponent, fonts::Font};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, test_module,
};

#[test]
fn check_short_text() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(HorizontalScrollingTextComponent {
            color: Color::red(),
            text: "hi".to_string(),
            pos: (0, 63).into(),
            font: Font::Font5x5,
            cutoff_x: 0,
            internal_tick: Cell::new(0),
        })],
        vec![HorizontalScrollingTextComponent::animate(
            0,
            NonZeroU8::new(1).unwrap(),
            -64,
            NonZeroU32::new(71).unwrap(),
            false,
        )],
        vec![],
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_short_1.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_short_24.hex")).trim(),
        render_to_hex(&mut clock, module, 24),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_short_64.hex")).trim(),
        render_to_hex(&mut clock, module, 64),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_short_68.hex")).trim(),
        render_to_hex(&mut clock, module, 68),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 70),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 80),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_long_text() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(HorizontalScrollingTextComponent {
            color: Color::red(),
            text: "hi this text is so long".to_string(),
            pos: (0, 63).into(),
            font: Font::Font5x5,
            cutoff_x: 0,
            internal_tick: Cell::new(0),
        })],
        vec![HorizontalScrollingTextComponent::animate(
            0,
            NonZeroU8::new(1).unwrap(),
            -64,
            NonZeroU32::new(180).unwrap(),
            false,
        )],
        vec![],
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_1.hex")).trim(),
        render_to_hex(&mut clock, module, 1),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_14.hex")).trim(),
        render_to_hex(&mut clock, module, 14),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_41.hex")).trim(),
        render_to_hex(&mut clock, module, 41),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_64.hex")).trim(),
        render_to_hex(&mut clock, module, 64),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_79.hex")).trim(),
        render_to_hex(&mut clock, module, 79),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_114.hex")).trim(),
        render_to_hex(&mut clock, module, 114),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_164.hex")).trim(),
        render_to_hex(&mut clock, module, 164),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_long_177.hex")).trim(),
        render_to_hex(&mut clock, module, 177),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 178),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 186),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_short_text_limited_area() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(HorizontalScrollingTextComponent {
            color: Color::red(),
            text: "hi".to_string(),
            pos: (10, 54).into(),
            font: Font::Font5x5,
            cutoff_x: 10,
            internal_tick: Cell::new(113),
        })],
        vec![HorizontalScrollingTextComponent::animate(
            0,
            NonZeroU8::new(1).unwrap(),
            -64,
            NonZeroU32::new(61).unwrap(),
            false,
        )],
        vec![],
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 9),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump(
            "horizontal_scrolling_text_short_limited_area_10.hex"
        ))
        .trim(),
        render_to_hex(&mut clock, module, 10),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump(
            "horizontal_scrolling_text_short_limited_area_20.hex"
        ))
        .trim(),
        render_to_hex(&mut clock, module, 20),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump(
            "horizontal_scrolling_text_short_limited_area_40.hex"
        ))
        .trim(),
        render_to_hex(&mut clock, module, 40),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump(
            "horizontal_scrolling_text_short_limited_area_55.hex"
        ))
        .trim(),
        render_to_hex(&mut clock, module, 55),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump(
            "horizontal_scrolling_text_short_limited_area_59.hex"
        ))
        .trim(),
        render_to_hex(&mut clock, module, 59),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 60),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 64),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_complex() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(HorizontalScrollingTextComponent {
            color: Color::red(),
            text: "hi".to_string(),
            pos: (10, 63).into(),
            font: Font::Font12x24,
            cutoff_x: 10,
            internal_tick: Cell::new(0),
        })],
        vec![HorizontalScrollingTextComponent::animate(
            0,
            NonZeroU8::new(1).unwrap(),
            -31,
            NonZeroU32::new(43).unwrap(),
            true,
        )],
        vec![],
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_0.hex")).trim(),
        render_to_hex(&mut clock, module, 0),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_10.hex")).trim(),
        render_to_hex(&mut clock, module, 10),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_20.hex")).trim(),
        render_to_hex(&mut clock, module, 20),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_23.hex")).trim(),
        render_to_hex(&mut clock, module, 23),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_35.hex")).trim(),
        render_to_hex(&mut clock, module, 35),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_41.hex")).trim(),
        render_to_hex(&mut clock, module, 41),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 42),
        "Component does not match known good hexdump!"
    );

    assert_eq!(
        hex_from_file(get_dump("horizontal_scrolling_text_complex_0.hex")).trim(),
        render_to_hex(&mut clock, module, 44),
        "Component does not match known good hexdump!"
    );
}
