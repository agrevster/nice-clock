use std::{
    cell::Cell,
    num::{NonZeroU8, NonZeroU32},
};

use common::clock::{
    color::Color,
    components::{VerticalScrollingTextComponent, animate_internal_tick_component},
    fonts::Font,
};
use simulator::test_utils::{
    TestingConnector, get_dump, hex_from_file, render_to_hex, test_module,
};

#[test]
fn check_short_text() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(VerticalScrollingTextComponent {
            color: Color::blue(),
            pos: (31, 9).into(),
            internal_tick: Cell::new(24),
            text: "Hello world".to_string(),
            font: Font::Font5x8,
            cutoff_y: 0,
            line_spacing: 0,
        })],
        vec![animate_internal_tick_component(
            0,
            NonZeroU8::new(1).unwrap(),
            -3,
            NonZeroU32::new(43).unwrap(),
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
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_short_4.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_short_9.hex")).trim(),
        render_to_hex(&mut clock, module, 9),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_short_20.hex")).trim(),
        render_to_hex(&mut clock, module, 20),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_short_35.hex")).trim(),
        render_to_hex(&mut clock, module, 35),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_short_40.hex")).trim(),
        render_to_hex(&mut clock, module, 40),
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
        vec![Box::new(VerticalScrollingTextComponent {
            color: Color::blue(),
            pos: (31, 9).into(),
            internal_tick: Cell::new(0),
            text: "Hello world how does longer text work?".to_string(),
            font: Font::Font5x8,
            cutoff_y: 0,
            line_spacing: 0,
        })],
        vec![animate_internal_tick_component(
            0,
            NonZeroU8::new(1).unwrap(),
            -3,
            NonZeroU32::new(70).unwrap(),
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
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_long_4.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_long_9.hex")).trim(),
        render_to_hex(&mut clock, module, 9),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_long_30.hex")).trim(),
        render_to_hex(&mut clock, module, 30),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_long_35.hex")).trim(),
        render_to_hex(&mut clock, module, 35),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_long_43.hex")).trim(),
        render_to_hex(&mut clock, module, 43),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_long_64.hex")).trim(),
        render_to_hex(&mut clock, module, 64),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 65),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 70),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_with_cutoff() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(VerticalScrollingTextComponent {
            color: Color::blue(),
            pos: (31, 20).into(),
            internal_tick: Cell::new(0),
            text: "Hello :)\nNewline".to_string(),
            font: Font::Font5x8,
            cutoff_y: 20,
            line_spacing: 0,
        })],
        vec![animate_internal_tick_component(
            0,
            NonZeroU8::new(1).unwrap(),
            -3,
            NonZeroU32::new(32).unwrap(),
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
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_cutoff_4.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_cutoff_9.hex")).trim(),
        render_to_hex(&mut clock, module, 9),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_cutoff_15.hex")).trim(),
        render_to_hex(&mut clock, module, 15),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_cutoff_21.hex")).trim(),
        render_to_hex(&mut clock, module, 21),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_cutoff_23.hex")).trim(),
        render_to_hex(&mut clock, module, 23),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_cutoff_28.hex")).trim(),
        render_to_hex(&mut clock, module, 28),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_positive_spacing() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(VerticalScrollingTextComponent {
            color: Color::blue(),
            pos: (31, 15).into(),
            internal_tick: Cell::new(0),
            text: "Hello :)\nNewline".to_string(),
            font: Font::Font5x8,
            cutoff_y: 10,
            line_spacing: 4,
        })],
        vec![animate_internal_tick_component(
            0,
            NonZeroU8::new(1).unwrap(),
            -3,
            NonZeroU32::new(45).unwrap(),
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
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_4.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_10.hex")).trim(),
        render_to_hex(&mut clock, module, 10),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_16.hex")).trim(),
        render_to_hex(&mut clock, module, 16),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_21.hex")).trim(),
        render_to_hex(&mut clock, module, 21),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_30.hex")).trim(),
        render_to_hex(&mut clock, module, 30),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_42.hex")).trim(),
        render_to_hex(&mut clock, module, 42),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 43),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 50),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_negative_spacing() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(VerticalScrollingTextComponent {
            color: Color::blue(),
            pos: (31, 15).into(),
            internal_tick: Cell::new(0),
            text: "Hello :)\nNewline".to_string(),
            font: Font::Font5x8,
            cutoff_y: 10,
            line_spacing: -4,
        })],
        vec![animate_internal_tick_component(
            0,
            NonZeroU8::new(1).unwrap(),
            -3,
            NonZeroU32::new(36).unwrap(),
            true,
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
        render_to_hex(&mut clock, module, 3),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_short_4.hex")).trim(),
        render_to_hex(&mut clock, module, 4),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_short_10.hex")).trim(),
        render_to_hex(&mut clock, module, 10),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_short_16.hex")).trim(),
        render_to_hex(&mut clock, module, 16),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_short_21.hex")).trim(),
        render_to_hex(&mut clock, module, 21),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_short_30.hex")).trim(),
        render_to_hex(&mut clock, module, 30),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("vertical_scrolling_text_spacing_short_34.hex")).trim(),
        render_to_hex(&mut clock, module, 34),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 35),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 36),
        "Component does not match known good hexdump!"
    );
}

#[test]
fn check_pos_more_than_cutoff_blank() {
    let mut clock = TestingConnector::default();
    Font::load_fonts().expect("Failed to load fonts");
    let module = &mut test_module(
        vec![Box::new(VerticalScrollingTextComponent {
            color: Color::blue(),
            pos: (18, 0).into(),
            internal_tick: Cell::new(-3 + 3),
            text: "you will never see this".to_string(),
            font: Font::Font5x8,
            cutoff_y: 20,
            line_spacing: 0,
        })],
        vec![animate_internal_tick_component(
            0,
            NonZeroU8::new(1).unwrap(),
            -3,
            NonZeroU32::new(36).unwrap(),
            true,
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
        render_to_hex(&mut clock, module, 10),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 20),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 25),
        "Component does not match known good hexdump!"
    );
    assert_eq!(
        hex_from_file(get_dump("empty.hex")).trim(),
        render_to_hex(&mut clock, module, 30),
        "Component does not match known good hexdump!"
    );
}
