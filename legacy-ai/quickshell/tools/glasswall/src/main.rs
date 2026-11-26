//! qs-glasswall: the top strip of the wallpaper exactly as awww shows it (awww img --resize crop,
//! filter Lanczos3). Same crates and the same calls as awww 0.12.1: image decodes, fast_image_resize scales
//! with a centered crop. The bar's Shell glass then blurs the very same pixels Hyprland blurs behind kitty.
//!
//! Usage: qs-glasswall <image> <screen width> <screen height> <rows> <output.ppm>
//! Writes the first <rows> rows of the screen-sized wallpaper as a binary PPM (written to a temporary file
//! first and then renamed, so the bar never reads a half written file).

use fast_image_resize::images::{Image, ImageRef};
use fast_image_resize::{FilterType, PixelType, ResizeAlg, ResizeOptions, Resizer};
use std::io::{Cursor, Write};

fn main() {
    if let Err(e) = run() {
        eprintln!("qs-glasswall: {e}");
        std::process::exit(1);
    }
}

fn number(arg: &str, name: &str) -> Result<u32, String> {
    match arg.parse::<u32>() {
        Ok(v) if v > 0 => Ok(v),
        _ => Err(format!("{name} must be a positive number, got {arg:?}")),
    }
}

fn run() -> Result<(), String> {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 6 {
        return Err("usage: qs-glasswall <image> <screen width> <screen height> <rows> <output.ppm>".into());
    }
    let width = number(&args[2], "screen width")?;
    let height = number(&args[3], "screen height")?;
    let rows = number(&args[4], "rows")?.min(height);
    let out = &args[5];

    // Like awww: read the file, guess the format from the content, decode, 3 channels
    let bytes = std::fs::read(&args[1]).map_err(|e| format!("failed to read {}: {e}", args[1]))?;
    let img = image::ImageReader::new(Cursor::new(&bytes))
        .with_guessed_format()
        .map_err(|e| format!("failed to read image: {e}"))?
        .decode()
        .map_err(|e| format!("failed to decode image: {e}"))?
        .into_rgb8();

    // Like awww img_resize_crop: unchanged if the size already fits, otherwise scaled and cropped centered
    let (img_w, img_h) = img.dimensions();
    let pixels: Vec<u8> = if (img_w, img_h) == (width, height) {
        img.into_raw()
    } else {
        let src = ImageRef::new(img_w, img_h, img.as_raw(), PixelType::U8x3).map_err(|e| e.to_string())?;
        let mut dst = Image::new(width, height, PixelType::U8x3);
        let options = ResizeOptions::new()
            .resize_alg(ResizeAlg::Convolution(FilterType::Lanczos3))
            .fit_into_destination(Some((0.5, 0.5)));
        Resizer::new()
            .resize(&src, &mut dst, Some(&options))
            .map_err(|e| e.to_string())?;
        dst.into_vec()
    };

    let tmp = format!("{out}.tmp");
    let len = width as usize * rows as usize * 3;
    let mut file = std::fs::File::create(&tmp).map_err(|e| format!("failed to create {tmp}: {e}"))?;
    write!(file, "P6\n{width} {rows}\n255\n").map_err(|e| e.to_string())?;
    file.write_all(&pixels[..len]).map_err(|e| e.to_string())?;
    drop(file);
    std::fs::rename(&tmp, out).map_err(|e| format!("failed to write {out}: {e}"))?;
    Ok(())
}
