
const dwm = @cImport(@cInclude("dwm.h"));

pub fn main() void {
    _ = dwm.start();
}
