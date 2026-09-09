use std::rc::Rc;
use std::{collections::HashMap, sync::OnceLock};

use log::error;

use crate::clock::{color::Color, errors::ClockError, module::ClockModule};
use crate::{
    VoidClockResult,
    utils::{LogUnwrap, assets_dir},
};

///Used to store PPM images.
pub struct PPM {
    pub width: u8,
    pub height: u8,
    pub pixels: Vec<Color>,
}

impl PPM {
    ///Parses a `PPM` image from bytes. `image_name` is used for errors.
    pub fn parse(data: &[u8], image_name: &str) -> Result<PPM, ClockError> {
        let width: OnceLock<u8> = OnceLock::new();
        let height: OnceLock<u8> = OnceLock::new();
        let max_color_value: OnceLock<u16> = OnceLock::new();

        let mut pixels: Vec<Color> = Vec::new();

        // Magic number is always the first line.
        let magic_end = data.iter().position(|&b| b == b'\n').ok_or_else(|| {
            ClockError::ppm_image_parsing(image_name, "Failed to get image header!")
        })?;

        if &data[..magic_end] != b"P6" {
            return Err(ClockError::ppm_image_parsing(
                image_name,
                "Invalid image filetype!",
            ));
        }
        let mut pos = magic_end + 1;

        while pos < data.len() {
            let end = data[pos..]
                .iter()
                .position(|&b| b == b'\n')
                .map_or(data.len(), |i| pos + i);
            let line = &data[pos..end];
            pos = (end + 1).min(data.len());

            if line.starts_with(b"#") {
                continue;
            } else if line.first().is_some_and(u8::is_ascii_digit)
                && (width.get().is_none() && height.get().is_none())
            {
                let split_at = line.iter().position(|&b| b == b' ').ok_or_else(|| {
                    ClockError::ppm_image_parsing(
                        image_name,
                        "Failed to get image width and height!",
                    )
                })?;
                let (w_bytes, h_bytes) = (&line[..split_at], &line[split_at + 1..]);

                let w_str = std::str::from_utf8(w_bytes).map_err(|e| {
                    error!("Failed to parse image width as utf8: {e}");
                    ClockError::ppm_image_parsing(image_name, "Failed parse image width number!")
                })?;
                let h_str = std::str::from_utf8(h_bytes).map_err(|e| {
                    error!("Failed to parse image height as utf8: {e}");
                    ClockError::ppm_image_parsing(image_name, "Failed parse image height number!")
                })?;

                width
                    .set(w_str.parse().map_err(|e| {
                        error!("Failed to parse image width as number: {e}");
                        ClockError::ppm_image_parsing(
                            image_name,
                            "Failed parse image width number!",
                        )
                    })?)
                    .unwrap_and_log("Failed to set width because it is already set!");

                height
                    .set(h_str.parse().map_err(|e| {
                        error!("Failed to parse image height as number: {e}");
                        ClockError::ppm_image_parsing(
                            image_name,
                            "Failed parse image height number!",
                        )
                    })?)
                    .unwrap_and_log("Failed to set height because it is already set!");
            } else if line.first().is_some_and(u8::is_ascii_digit)
                && max_color_value.get().is_none()
            {
                let line_str = std::str::from_utf8(line).map_err(|e| {
                    error!("Failed to parse image max_color as utf8: {e}");
                    ClockError::ppm_image_parsing(image_name, "Failed parse image height number!")
                })?;

                max_color_value
                    .set(line_str.parse().map_err(|e| {
                        error!("Failed to parse image max_color as number: {e}");
                        ClockError::ppm_image_parsing(
                            image_name,
                            "Failed parse image height number!",
                        )
                    })?)
                    .unwrap_and_log("Failed to set max color because it is already set!");
                break;
            }
        }

        //Invalid headers have no width, height, or max color
        if width.get().is_none() || height.get().is_none() || max_color_value.get().is_none() {
            return Err(ClockError::ppm_image_parsing(
                image_name,
                "Failed to parse PPM header!",
            ));
        }

        //Invalid colors are more than 255
        if *max_color_value.get().unwrap() > 255 {
            return Err(ClockError::ppm_image_parsing(
                image_name,
                "Failed to parse PPM header: color too big!",
            ));
        }

        let pixel_data: &[u8] = &data[pos..];
        let pixel_count: usize = *width.get().unwrap() as usize * *height.get().unwrap() as usize;

        if pixel_data.len() < pixel_count * 3 {
            return Err(ClockError::ppm_image_parsing(
                image_name,
                "Failed to parse PPM body: not enough pixels have been set!",
            ));
        }

        pixel_data.chunks_exact(3).for_each(|colors| {
            pixels.push(Color {
                r: colors[0],
                g: colors[1],
                b: colors[2],
            });
        });

        Ok(PPM {
            height: *height.get().unwrap(),
            width: *width.get().unwrap(),
            pixels,
        })
    }
}

#[derive(Default)]
///Used to store `PPM` images for the clock and its modules.
pub struct ImageStore {
    images: HashMap<String, Rc<PPM>>,
}

impl ImageStore {
    ///Attempts to locate an image from the `ImageStore`. If the image is not found returns a `ClockError`.
    pub fn get_image(&mut self, name: &str) -> Result<Rc<PPM>, ClockError> {
        self.images
            .get(name)
            .map(Rc::clone)
            .ok_or_else(|| ClockError::asset_not_found(format!("{name}.ppm")))
    }

    /// Loads a given image found in `assets/images/{filename}`.
    /// Returns an error if the image file cannot be found or there are parsing errors.
    fn load_image_from_file(&mut self, filename: String) -> VoidClockResult {
        let mut assets = assets_dir();

        let ppm_filename = format!("{filename}.ppm");

        assets.push("images");
        assets.push(&ppm_filename);

        let file_data = std::fs::read(&assets).map_err(|e| ClockError::file_error(e, assets))?;

        self.images.insert(
            filename,
            Rc::new(PPM::parse(
                &file_data,
                &(ppm_filename.to_string() + ".ppm"),
            )?),
        );

        Ok(())
    }

    ///Loads all of a given `module`'s images into the `ImageStore`. A `ClockError` is returned if
    ///an issue occurs while loading the image.
    pub fn load_images_for_module(&mut self, module: &ClockModule) -> VoidClockResult {
        for image in &module.images_names {
            self.load_image_from_file(image.clone())?
        }
        Ok(())
    }

    ///Unloads all images from the `ImageStore`.
    pub fn clear(&mut self) {
        self.images.clear();
    }
}

#[cfg(test)]
mod test {

    use std::time::Duration;

    use crate::clock::{
        color::Color,
        components::RootComponent,
        images::{ImageStore, PPM},
        module::ClockModule,
    };

    #[test]
    fn test_image_parsing() {
        let expected = "     \nG   G\n     \n     \nR   R\n RRR \n     \n     \n";

        let mut actual = String::new();

        let file_data = std::fs::read("../assets/images/test.ppm").expect("Failed to open file");
        let image = PPM::parse(&file_data, "test.ppm").expect("Failed to parse PPM!");

        let red = Color::red();
        let green = Color::green();

        for y in 0..image.height {
            for x in 0..image.width {
                let pixel = image
                    .pixels
                    .get((y * image.width + x) as usize)
                    .expect("Failed to get pixel!");
                let sym = if pixel == &red {
                    'R'
                } else if pixel == &green {
                    'G'
                } else {
                    ' '
                };
                print!("{}", sym);
                actual.push(sym);
            }
            actual.push('\n');
            println!()
        }
        assert_eq!(expected.to_string(), actual);
    }

    #[test]
    fn test_image_store_not_found() {
        let mut store = ImageStore::default();
        assert!(store.get_image("test").is_err())
    }

    #[test]
    fn test_image_store_load_from_file_and_get() {
        let mut store = ImageStore::default();
        store.load_image_from_file("test".to_string()).unwrap();

        let image = store.get_image("test").unwrap();
        assert_eq!(image.width, 5);
        assert_eq!(image.height, 8);

        let mut actual = String::new();

        let expected = "     \nG   G\n     \n     \nR   R\n RRR \n     \n     \n";
        let red = Color::red();
        let green = Color::green();

        for y in 0..image.height {
            for x in 0..image.width {
                let pixel = image
                    .pixels
                    .get((y * image.width + x) as usize)
                    .expect("Failed to get pixel!");
                let sym = if pixel == &red {
                    'R'
                } else if pixel == &green {
                    'G'
                } else {
                    ' '
                };
                print!("{}", sym);
                actual.push(sym);
            }
            actual.push('\n');
            println!()
        }
        assert_eq!(expected.to_string(), actual);
    }

    #[test]
    fn test_load_images_for_module() {
        let mut store = ImageStore::default();

        let module = ClockModule {
            name: "test_module".to_string(),
            time_limt: Duration::ZERO,
            root_compoent: RootComponent::new(Vec::new(), Vec::new()),
            images_names: vec![
                "cat".to_string(),
                "fireworks".to_string(),
                "github".to_string(),
            ],
        };

        assert!(store.load_images_for_module(&module).is_ok());

        for image in module.images_names {
            store.get_image(&image).unwrap();
        }
    }
}
